import 'package:proxy/utils/utils.dart';
import 'package:proxy/inbounds/base.dart';

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
    if (allowedUser != ['']) {}
    return false;
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
    for (var i = 0, len = rulesConfig.length; i < len; ++i) {
      rules.add(RouteRule(config: rulesConfig[i]));
    }
  }

  bool match(Link link) {
    return false;
  }
}
