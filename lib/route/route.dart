import 'package:crypto/crypto.dart';
import 'package:proxy/balance/balancer.dart';
import 'package:proxy/outbounds/base.dart';
import 'package:quiver/collection.dart';

import 'package:proxy/dns/dns.dart';
import 'package:proxy/route/matcher.dart';
import 'package:proxy/utils/utils.dart';
import 'package:proxy/utils/const.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/obj_list.dart';

class RouteRule {
  List<List<int>> allowedUser = [];
  List<Pattern> ipPattern = [];
  List<Pattern> domainPattern = [];
  List<Pattern> portPattern = [];

  Balancer? balancer;
  DNS? dns;

  Map<String, dynamic> config;

  RouteRule({required this.config}) {
    List<dynamic> outList = [];

    var temp = getValue(config, 'outbound', '');
    if (temp != '') {
      if (temp.runtimeType == String) {
        outList.add(temp as String);
      } else if (temp.runtimeType == List) {
        outList = temp;
      }
    }

    var bal = getValue(config, 'balance', '');
    if (outList.isNotEmpty && bal != '') {
      throw Exception(
          "There are both 'outbound' and 'balance' in rules, don't know which to use.");
    }

    if (bal != '') {
      balancer = balancerList[bal];
    } else if (outList.isNotEmpty) {
      balancer = Balancer.load(out: config['outbound']);
    } else {
      throw Exception("'outbound' and 'balance' can not neither be empty.");
    }

    buildUser();
    buildDomainPattern();
    buildIPPattern();
    buildPortPattern();

    buildCache(); // after build pattern.
    buildDNS();
  }

  void buildDNS() {
    var dnsTag = getValue(config, 'dns', '');
    if (dnsTag == '') {
      // use default DNS.
      dnsTag = 'txDOH';
    }
    if (!dnsList.containsKey(dnsTag)) {
      throw Exception('unknow dns tag.');
    }
    dns = dnsList[dnsTag]!;
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

  void buildPortPattern() {
    List<dynamic> portList = getValue(config, 'port', ['']);

    if (listsEqual(portList, [''])) {
      portList = [];
    }

    for (var i = 0, len = portList.length; i < len; ++i) {
      portPattern.add(PortPattern(pattern: portList[i]));
    }
  }

  void buildIPPattern() {
    dynamic temp = getValue(config, 'ip', ['']);
    List<dynamic> ipList = [];
    if (temp.runtimeType == String) {
      ipList.add(temp);
    } else {
      ipList = temp;
    }

    Pattern pattern;
    for (var i = 0, len = ipList.length; i < len; ++i) {
      if (ipList[i].runtimeType == String) {
        if (ipList[i] == '') {
          continue;
        }
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

  bool matchAllowedUser(Link link) {
    for (var i = 0, len = allowedUser.length; i < len; ++i) {
      if (listsEqual(allowedUser[i], link.userID)) {
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

    if (portPattern.isNotEmpty &&
        link.targetport != 0 &&
        !await matchPort(link.targetport.toString())) {
      return false;
    }

    var addressType = link.targetAddress!.type;

    if (addressType == AddressType.domain) {
      if (domainPattern.isNotEmpty &&
          !await matchDomain(link.targetAddress!.address)) {
        return false;
      }

      if (ipPattern.isNotEmpty) {
        var ip = await dns!.resolveWithCache(link.targetAddress!.address);
        link.targetIP = ip;
        if (!await matchIP(ip)) {
          return false;
        }
      }
    } else {
      if (domainPattern.isNotEmpty) {
        return false;
      }

      if (ipPattern.isNotEmpty && !await matchIP(link.targetAddress!.address)) {
        return false;
      }
    }

    return true;
  }

  Future<bool> matchPort(String input) async {
    return await patternMatch(input, portPattern);
  }

  Future<bool> matchDomain(String input) async {
    return await patternMatch(input, domainPattern);
  }

  Future<bool> matchIP(String input) async {
    return await patternMatch(input, ipPattern);
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

  OutboundStruct getOut() {
    return balancer!.dispatch();
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

  Future<OutboundStruct> match(Link link) async {
    for (var i = 0, len = rules.length; i < len; ++i) {
      if (await rules[i].match(link)) {
        return rules[i].getOut();
      }
    }
    return rules[rules.length - 1].getOut();
  }
}
