import 'dart:io';

import 'package:proxy/utils/utils.dart';
import 'package:dns_client/dns_client.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/obj_list.dart';

Map<String, dynamic> cachedDNS = {};
var doh = DnsOverHttps('https://doh.pub/dns-query');

class RouteRule {
  late String outbound;
  late String matchAddress;
  late List<String> allowedUser;

  Map<String, dynamic> config;

  RouteRule({required this.config}) {
    outbound = config['outbound'];

    allowedUser = getValue(config, 'allowedUser', ['']);
    matchAddress = getValue(config, 'address', '');
  }

  Future<bool> match(Link link) async {
    if (allowedUser != [''] && !allowedUser.contains(link.userID)) {
      return false;
    }
    String ip = '';
    if (link.targetAddress.type == 'domain') {
      String domain = link.targetAddress.address;
      if (cachedDNS.containsKey(domain)) {
        ip = cachedDNS[domain];
      } else {
      var record =  await doh.lookupHttps('');
      record.toString();
      }
    } else {
      ip = link.targetAddress.address;
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

  String _match(Link link) {
    for (var i = 0, len = rules.length; i < len; ++i) {
      if (rules[i].match(link)) {
        return rules[i].outbound;
      }
    }
    return rules[rules.length - 1].outbound;
  }

  String match(Link link) {
    var outbound = _match(link);
    if (!outboundsList.containsKey(outbound)) {
      throw 'There are no route tag named "$outbound".';
    }
    return outbound;
  }
}
