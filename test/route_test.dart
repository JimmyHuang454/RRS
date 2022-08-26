import 'package:test/test.dart';

import 'package:proxy/handler.dart';
import 'package:proxy/obj_list.dart';
import 'package:proxy/route/route.dart';

import 'package:dns_client/dns_client.dart';

void main() {
  test('route match', () async {
    buildRoute('test_route', {
      "rules": [
        {
          "user": ["1"],
          "domain": ["bc.com"],
          "outbound": "out1"
        }
      ]
    });

    expect(routeList.containsKey('test_route'), true);

    var obj = routeList['test_route'];
    expect(obj!.rules.length, 1);

    var rules = obj.rules[0];
    expect(rules.checkDomain('abc.com'), true);

    var doh2 = DnsOverHttps('https://doh.pub/dns-query');
    var record = await doh2.lookupHttps('tsinghua.edu.cn');
    record = await doh2.lookupHttps('sgu.edu.cn');
  });
}
