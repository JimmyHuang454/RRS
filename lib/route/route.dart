import 'dart:io';

import 'package:dns_client/dns_client.dart';
import 'package:crypto/crypto.dart';
import 'package:proxy/route/matcher.dart';
import 'package:quiver/collection.dart';

import 'package:proxy/utils/utils.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/obj_list.dart';

var doh = DnsOverHttps('https://doh.pub/dns-query');

class RouteRule {
  List<String> outbound = [];
  List<List<int>> allowedUser = [];
  List<Pattern> ipPattern = [];
  List<Pattern> domainPattern = [];

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

    buildUser();
    buildDomainPattern();
    buildIPPattern();

    buildCache(); // after build pattern.
  }

  void buildCache() {
    var useCache = getValue(config, 'cache.enable', false);

    if (!useCache) {
      return;
    }

    var cacheSize = getValue(config, 'cache.cacheSize', 500);

    for (var i = 0, len = ipPattern.length; i < len; ++i) {
      ipPattern[i].setCache(useCache, cacheSize);
    }

    for (var i = 0, len = domainPattern.length; i < len; ++i) {
      domainPattern[i].setCache(useCache, cacheSize);
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

  bool matchAllowedUser(Link link) {
    for (var i = 0, len = allowedUser.length; i < len; ++i) {
      if (listsEqual(allowedUser[i], link.userID)) {
        return true;
      }
    }
    return false;
  }

  Future<bool> patternMatch(String pattern, List<Pattern> patternList) async {
    if (pattern == '') {
      return false;
    }

    for (var i = 0, len = patternList.length; i < len; ++i) {
      var res = await patternList[i].match2(pattern);
      if (res) {
        return true;
      }
    }
    return false;
  }

  Future<bool> match(Link link) async {
    // false means not match.

    if (allowedUser.isNotEmpty && !matchAllowedUser(link)) {
      return false;
    }

    var ip = link.targetIP;
    if (ipPattern.isNotEmpty && ip != '' && !await matchIP(ip)) {
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
        if (!await matchIP(ip)) {
          return false;
        }
      }
    }

    return true;
  }

  Future<bool> matchDomain(String input) async {
    return await patternMatch(input, domainPattern);
  }

  Future<bool> matchIP(String input) async {
    return await patternMatch(input, ipPattern);
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
