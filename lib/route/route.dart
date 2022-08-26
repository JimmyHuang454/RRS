import 'package:quiver/collection.dart';
import 'package:dns_client/dns_client.dart';

import 'package:proxy/route/mmdb.dart';
import 'package:proxy/utils/utils.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/obj_list.dart';

Map<String, dynamic> domainLocation = {}; // CN or not.
var doh = DnsOverHttps('https://doh.pub/dns-query');

class RouteRule {
  late String outbound;
  late List<String> domain;
  late List<String> ips;
  late List<String> allowedUser;
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
    if (listsEqual(domain, [''])) {
      domain = [];
    }

    ips = getValue(config, 'ip', ['']);
    if (listsEqual(ips, [''])) {
      ips = [];
    }
  }

  Future<bool> isChinaIP(Link link) async {
    String address = link.targetAddress.address;
    if (domainLocation.containsKey(address)) {
      return domainLocation[address];
    }

    var ip = address;
    if (link.targetAddress.type == 'domain') {
      var record = await doh.lookup(address);
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

  bool checkDomain(Link link) {
    for (var i = 0, len = domain.length; i < len; ++i) {
      var re = RegExp(domain[i]);
      if (re.hasMatch(link.targetAddress.address)) {
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

    if (domain.isNotEmpty && !checkDomain(link)) {
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

  Future<String> _match(Link link) async {
    for (var i = 0, len = rules.length; i < len; ++i) {
      if (await rules[i].match(link)) {
        return rules[i].outbound;
      }
    }
    return rules[rules.length - 1].outbound;
  }

  Future<String> match(Link link) async {
    Stopwatch stopwatch = Stopwatch()..start();
    var outbound = await _match(link);
    if (!outboundsList.containsKey(outbound)) {
      throw 'There are no route tag named "$outbound".';
    }
    print('route ${stopwatch.elapsed}');
    return outbound;
  }
}
