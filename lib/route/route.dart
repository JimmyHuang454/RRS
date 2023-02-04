import 'dart:io';

import 'package:dns_client/dns_client.dart';
import 'package:crypto/crypto.dart';
import 'package:dcache/dcache.dart';
import 'package:quiver/collection.dart';

import 'package:proxy/route/mmdb.dart';
import 'package:proxy/utils/utils.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/obj_list.dart';

var doh = DnsOverHttps('https://doh.pub/dns-query');

class DomainPattern {
  String type = 'substring';
  String pattern;
  DomainPattern(this.type, this.pattern);
}

class IPPattern {
  String type = 'db';
  String pattern;

  late MMDB db;
  IPPattern(this.type, this.pattern);
}

class RouteRule {
  List<String> outbound = [];
  List<List<int>> allowedUser = [];
  List<IPPattern> ipPattern = [];
  List<DomainPattern> domainPattern = [];

  Map<String, dynamic> config;

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

    var allowedUserTemp = getValue(config, 'allowedUser', ['']);
    for (var i = 0, len = allowedUserTemp.length; i < len; ++i) {
      if (allowedUserTemp[i] == '' ||
          allowedUserTemp[i].runtimeType != String) {
        continue;
      }
      allowedUser.add(sha224.convert(allowedUserTemp[i]).toString().codeUnits);
    }

    buildDomainPattern();
    buildIPPattern();
  }

  void buildIPPattern() {
    List<dynamic> ipList = getValue(config, 'ip', ['']);

    if (listsEqual(ipList, [''])) {
      ipList = [];
    }

    for (var i = 0, len = ipList.length; i < len; ++i) {
      IPPattern ip;
      if (ipList[i].runtimeType == String) {
        var temp = ipList[i] as String;
        if (temp.contains("/")) {
          ip = IPPattern('CIDR', temp);
        } else {
          ip = IPPattern('full', temp);
        }
      } else {
        var temp = ipList[i] as dynamic;
        if (!temp.containsKey('ipdb') || !temp.containsKey('type')) {
          throw "missing ipdb or type in ip RouteRule.";
        }
        var name = temp['ipdb'];
        ip = IPPattern('db', temp['type']);
        if (!ipdbList.containsKey(name)) {
          throw "wrong ipdb name: $name.";
        }
        ip.db = ipdbList[name]!;
      }
      ipPattern.add(ip);
    }
  }

  void buildDomainPattern() {
    var domain = getValue(config, 'domain', ['']);
    if (listsEqual(domain, [''])) {
      domain = [];
    }

    for (var i = 0, len = domain.length; i < len; ++i) {
      var pos = domain[i].indexOf(':');
      DomainPattern dp;
      if (pos == -1) {
        dp = DomainPattern('substring', domain[i]);
      } else {
        var str = domain[i] as String;
        var type = str.substring(0, pos);
        var pattern = str.substring(pos + 1);
        dp = DomainPattern(type, pattern);
      }
      domainPattern.add(dp);
    }
  }

  Future<String> resolveDomain(String domain) async {
    List<InternetAddress> record;
    record = await doh.lookup(domain);

    try {
      record = await doh.lookup(domain);
      if (record.isNotEmpty) {
        return record[0].address;
      }
    } catch (e) {
      return "";
    }
    return "";
  }

  Future<bool> checkIP(String ip) async {
    for (var i = 0, len = ipPattern.length; i < len; ++i) {
      var p = ipPattern[i];
      if (p.type == 'full' && ip == p.pattern) {
        return true;
      } else if (p.type == 'db') {
        try {
          await p.db.load();
          var res = await p.db.search(ip);
          if (res != null && res['country']['iso_code'] == p.pattern) {
            return true;
          }
        } catch (e) {
          rethrow;
        }
      } else if (p.type == 'CIDR') {
        // TODO
      }
    }

    return false;
  }

  bool checkAllowedUser(Link link) {
    for (var i = 0, len = allowedUser.length; i < len; ++i) {
      if (listsEqual(allowedUser[i], link.userID)) {
        return true;
      }
    }
    return false;
  }

  bool checkDomain(String domain) {
    for (var i = 0, len = domainPattern.length; i < len; ++i) {
      var temp = domainPattern[i];
      if (temp.type == 'substring' && domain.contains(temp.pattern)) {
        return true;
      } else if (temp.type == 'regex' &&
          RegExp(temp.pattern).hasMatch(domain)) {
        return true;
      } else if (temp.type == 'full' && temp.pattern == domain) {
        return true;
      }
    }
    return false;
  }

  Future<bool> match(Link link) async {
    if (allowedUser.isNotEmpty && !checkAllowedUser(link)) {
      return false;
    }

    if (domainPattern.isNotEmpty &&
        link.targetAddress.type == 'domain' &&
        !checkDomain(link.targetAddress.address)) {
      return false;
    }

    String ip = link.targetAddress.address;
    if (link.targetAddress.type == 'domain') {
      ip = await resolveDomain(ip);
    }
    link.targetIP = ip;

    if (link.targetIP != '' && ipPattern.isNotEmpty && !await checkIP(ip)) {
      return false;
    }

    return true;
  }
}

class Route {
  late String tag;
  late String domainStrategy;
  List<RouteRule> rules = [];

  Map<String, dynamic> config;
  late Cache ruleCache;
  bool useCache = false;

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

    useCache = getValue(config, 'cache.enabled', false);
    if (useCache) {
      var storageSize = getValue(config, 'cache.size', 500);
      ruleCache = LruCache<String, String>(
        storage: InMemoryStorage<String, String>(storageSize),
      );
    }
  }

  String selectOut(RouteRule routeRule) {
    var temp = DateTime.now().millisecond % routeRule.outbound.length;
    return routeRule.outbound[temp];
  }

  Future<String> _match(Link link) async {
    for (var i = 0, len = rules.length; i < len; ++i) {
      if (await rules[i].match(link)) {
        return selectOut(rules[i]);
      }
    }
    return selectOut(rules[rules.length - 1]);
  }

  String checkCache(Link link) {
    var id = link.targetAddress.address;
    if (id != '') {
      var temp = ruleCache.get(id);
      if (temp != null) {
        return temp;
      }
      return '';
    }
    return '';
  }

  void saveCache(Link link, String res) {
    var id = link.targetAddress.address;
    if (id != '') {
      ruleCache.set(id, res);
    }
  }

  Future<String> match(Link link) async {
    if (useCache) {
      var temp = checkCache(link);
      if (temp != '') {
        logger.info('used DNS cache.');
        return temp;
      }
    }

    var outbound = await _match(link);

    if (useCache) {
      saveCache(link, outbound);
    }

    return outbound;
  }
}
