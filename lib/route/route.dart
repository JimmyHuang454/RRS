import 'package:proxy/utils/utils.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/obj_list.dart';

class RouteRule {
  late String outTag;
  late String matchAddress;
  late List<String> allowedUser;

  Map<String, dynamic> config;

  RouteRule({required this.config}) {
    outTag = config['outTag'];

    allowedUser = getValue(config, 'allowedUser', ['']);
    matchAddress = getValue(config, 'address', '');
  }

  bool match(Link link) {
    if (allowedUser != [''] && !allowedUser.contains(link.userID)) {
      return false;
    }
    return true;
  }
}

class Route {
  late String tag;
  late String domainStrategy;
  late List<RouteRule> rules;

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
        return rules[i].outTag;
      }
    }
    return rules[rules.length - 1].outTag;
  }

  String match(Link link) {
    var outTag = _match(link);
    if (!outboundsList.containsKey(outTag)) {
      throw 'There are no outbound named "$outTag".';
    }
    return outTag;
  }
}
