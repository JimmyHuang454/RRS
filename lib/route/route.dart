import 'dart:io';

import 'package:quiver/collection.dart';
import 'package:dns_client/dns_client.dart';

import 'package:proxy/route/mmdb.dart';
import 'package:proxy/utils/utils.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/obj_list.dart';

Map<String, dynamic> domainLocation = {}; // CN or not.
var doh = DnsOverHttps('https://doh.pub/dns-query');

class DomainPattern {
  String type = 'substring';
  String pattern;
  DomainPattern(this.type, this.pattern);
}

class RouteRule {
  late String outbound;
  late List<dynamic> domain;
  late List<dynamic> ips;
  late List<dynamic> allowedUser;
  List<DomainPattern> domainPattern = [];
  bool chinaOnly = false;

  Map<String, dynamic> config;

  RouteRule({required this.config}) {
    outbound = config['outbound'];

    chinaOnly = getValue(config, 'chinaOnly', false);

    allowedUser = getValue(config, 'allowedUser', ['']);
    if (listsEqual(allowedUser, [''])) {
      allowedUser = [];
    }

    domain = getValue(config, 'domain', ['']);
    buildDomainPattern();

    ips = getValue(config, 'ip', ['']);
    if (listsEqual(ips, [''])) {
      ips = [];
    }
  }

  void buildDomainPattern() {
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

  Future<bool> isChinaIP(Link link) async {
    String address = link.targetAddress.address;
    if (domainLocation.containsKey(address)) {
      return domainLocation[address];
    }

    var ip = address;
    if (link.targetAddress.type == 'domain') {
      List<InternetAddress> record;
      try {
        record = await doh.lookup(address);
      } catch (e) {
        domainLocation[address] = true;
        return true;
      }
      if (record.isEmpty) {
        return false;
      }
      ip = record[0].address; // resolve to IP.
    }

    var geo = await loadGeoIP();
    var res = await geo.search(ip);
    if (res == null) {
      domainLocation[address] = false;
    } else {
      domainLocation[address] = true; // CN
    }
    return domainLocation[address];
  }

  bool checkAllowedUser(Link link) {
    for (var i = 0, len = allowedUser.length; i < len; ++i) {
      if (listsEqual(allowedUser[i].codeUnits, link.userID)) {
        return true;
      }
    }
    return false;
  }

  bool checkDomain(String str) {
    for (var i = 0, len = domainPattern.length; i < len; ++i) {
      var temp = domainPattern[i];
      if (temp.type == 'substring' && str.contains(temp.pattern)) {
        return true;
      } else if (temp.type == 'regex' && RegExp(temp.pattern).hasMatch(str)) {
        return true;
      } else if (temp.type == 'full' && temp.pattern == str) {
        return true;
      }
    }
    return false;
  }

  bool checkIP(Link link) {
    // TODO
    return true;
  }

  Future<bool> match(Link link) async {
    if (allowedUser.isNotEmpty && !checkAllowedUser(link)) {
      return false;
    }

    if (domain.isNotEmpty && !checkDomain(link.targetAddress.address)) {
      return false;
    }

    if (ips.isNotEmpty && !checkIP(link)) {
      return false;
    }

    if (chinaOnly && !await isChinaIP(link)) {
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

  Future<String> match2(Link link) async {
    for (var i = 0, len = rules.length; i < len; ++i) {
      if (await rules[i].match(link)) {
        return rules[i].outbound;
      }
    }
    return rules[rules.length - 1].outbound;
  }

  Future<String> match(Link link) async {
    var outbound = await match2(link);
    if (!outboundsList.containsKey(outbound)) {
      throw 'There are no route tag named "$outbound".';
    }
    return outbound;
  }
}
