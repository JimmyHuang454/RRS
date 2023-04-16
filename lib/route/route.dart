import 'dart:io';

import 'package:dns_client/dns_client.dart';
import 'package:crypto/crypto.dart';
import 'package:dcache/dcache.dart';
import 'package:proxy/route/matcher.dart';
import 'package:quiver/collection.dart';

import 'package:proxy/route/mmdb.dart';
import 'package:proxy/utils/utils.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/obj_list.dart';

var doh = DnsOverHttps('https://doh.pub/dns-query');

class RouteRule {
  List<String> outbound = [];
  List<List<int>> allowedUser = [];
  List<Pattern> ipPattern = [];
  List<Pattern> domainPattern = [];
  bool useCache = false;

  Map<String, dynamic> config;
  Cache? ruleCache;

  RouteRule({required this.config}) {
    var temp = config['outbound'];
    if (temp.runtimeType == String) {
      outbound.add(temp);
    } else if (temp.runtimeType == List) {
      outbound = List<String>.from(temp);
    }

    for (var i = 0, len = outbound.length; i < len; ++i) {
      if (!outboundsList.containsKey(outbound[i])) {
        throw 'There are no route tag named "${outbound[i]}".';
      }
    }

    buildCache();
    buildUser();
    buildDomainPattern();
    buildIPPattern();
  }

  void buildCache() {
    useCache = getValue(config, 'cache.enabled', false);
    if (useCache) {
      var storageSize = getValue(config, 'cache.size', 500);
      ruleCache = LruCache<String, bool>(
        storage: InMemoryStorage<String, bool>(storageSize),
      );
    }
  }

  void buildUser() {
    var allowedUserTemp = getValue(config, 'allowedUser', ['']);
    for (var i = 0, len = allowedUserTemp.length; i < len; ++i) {
      if (allowedUserTemp[i] == '' ||
          allowedUserTemp[i].runtimeType != String) {
        continue;
      }
      allowedUser.add(sha224.convert(allowedUserTemp[i]).toString().codeUnits);
    }
  }

  void buildIPPattern() {
    List<dynamic> ipList = getValue(config, 'ip', ['']);

    if (listsEqual(ipList, [''])) {
      ipList = [];
    }

    Pattern pattern;
    for (var i = 0, len = ipList.length; i < len; ++i) {
      if (ipList[i].runtimeType == String) {
        var temp = ipList[i] as String;
        if (temp.contains("/")) {
          pattern = IPCIDRPattern(pattern: temp);
        } else {
          pattern = FullPattern(pattern: temp);
        }
      } else {
        var temp = ipList[i] as dynamic;
        if (!temp.containsKey('ipdb') || !temp.containsKey('type')) {
          throw "missing ipdb or type in ip RouteRule.";
        }
        pattern = MMDBPattern(pattern: temp['type'], dbName: temp['ipdb']);
      }
      ipPattern.add(pattern);
    }
  }

  void buildDomainPattern() {
    var domain = getValue(config, 'domain', ['']);
    if (listsEqual(domain, [''])) {
      domain = [];
    }

    Pattern pattern;
    for (var i = 0, len = domain.length; i < len; ++i) {
      var pos = domain[i].indexOf(':');
      if (pos == -1) {
        pattern = SubstringPattern(pattern: domain[i]);
      } else {
        var str = domain[i] as String;
        var type = str.substring(0, pos);
        var p = str.substring(pos + 1);
        if (type == 'regex') {
          pattern = RegexPattern(pattern: p);
        } else if (type == 'full') {
          pattern = FullPattern(pattern: p);
        } else {
          throw Exception('wrong pattern type named: $type');
        }
      }
      domainPattern.add(pattern);
    }
  }

  Future<String> resolveDomain(String domain) async {
    if (domain == '') {
      return '';
    }
    List<InternetAddress> record;
    record = await doh.lookup(domain);

    try {
      record = await doh.lookup(domain);
      if (record.isNotEmpty) {
        return record[0].address;
      }
    } catch (e) {
      return '';
    }
    return '';
  }

  Future<bool> checkIP(String ip) async {
    if (ip == '') {
      return false;
    }

    for (var i = 0, len = ipPattern.length; i < len; ++i) {
      var p = await ipPattern[i].match(ip);
      if (p) {
        return true;
      }
    }

    return false;
  }

  Future<bool> matchIP(Link link) async {
    if (link.targetIP == '') {
      return false;
    }

    var address = link.targetAddress!.address;

    if (useCache) {
      var temp = checkCache(address);
      if (temp != -1) {
        link.ipUseCache = true;
        return temp == 1 ? true : false;
      }
    }

    var res = await checkIP(link.targetIP);
    saveCache(address, res);
    return res;
  }

  bool checkAllowedUser(Link link) {
    for (var i = 0, len = allowedUser.length; i < len; ++i) {
      if (listsEqual(allowedUser[i], link.userID)) {
        return true;
      }
    }
    return false;
  }

  Future<bool> matchDomain(String domain) async {
    if (domain == '') {
      return false;
    }

    for (var i = 0, len = domainPattern.length; i < len; ++i) {
      var temp = await domainPattern[i].match(domain);
      if (temp) {
        return temp;
      }
    }
    return false;
  }

  int checkCache(String id) {
    if (id != '' && useCache) {
      var temp = ruleCache!.get(id);
      if (temp == null) {
        return -1;
      }
      if (temp) {
        return 1;
      }
      return 0;
    }
    return -1;
  }

  void saveCache(String id, bool res) {
    if (id != '' && useCache) {
      ruleCache!.set(id, res);
    }
  }

  Future<bool> match(Link link) async {
    // false means not match.

    if (allowedUser.isNotEmpty && !checkAllowedUser(link)) {
      return false;
    }

    var ip = link.targetIP;
    if (ipPattern.isNotEmpty && ip != '' && !await checkIP(ip)) {
      return false;
    }

    if (link.targetAddress!.type == 'domain') {
      var domain = link.targetAddress!.address;

      if (domainPattern.isNotEmpty && !await matchDomain(domain)) {
        return false;
      }

      if (ipPattern.isNotEmpty && ip == '') {
        ip = await resolveDomain(domain);
        link.targetIP = ip;
        if (!await checkIP(ip)) {
          return false;
        }
      }
    }

    return true;
  }
}

class Route {
  late String tag;
  late String domainStrategy;
  List<RouteRule> rules = [];

  Map<String, dynamic> config;

  Route({required this.config}) {
    tag = config['tag'];
    domainStrategy = getValue(config, 'domainStrategy', 'AsIs');
    var rulesConfig = config['rules'] as List<dynamic>;

    if (rulesConfig.isEmpty) {
      throw "rules can not be empty";
    }

    for (var i = 0, len = rulesConfig.length; i < len; ++i) {
      rules.add(RouteRule(config: rulesConfig[i]));
    }
  }

  String selectOut(RouteRule routeRule) {
    var temp = DateTime.now().millisecond % routeRule.outbound.length;
    return routeRule.outbound[temp];
  }

  Future<String> match(Link link) async {
    for (var i = 0, len = rules.length; i < len; ++i) {
      if (await rules[i].match(link)) {
        return selectOut(rules[i]);
      }
    }
    return selectOut(rules[rules.length - 1]);
  }
}
