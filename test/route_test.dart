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
          "domain": ["bc.com", "full:1.com", "regex:a.com"],
          "outbound": "out1"
        }
      ]
    });

    expect(routeList.containsKey('test_route'), true);

    var obj = routeList['test_route'];
    expect(obj!.rules.length, 1);

    var rules = obj.rules[0];
    expect(rules.domainPattern[0].type, 'substring');
    expect(rules.domainPattern[0].pattern, 'bc.com');
    expect(rules.domainPattern[1].type, 'full');
    expect(rules.domainPattern[1].pattern, '1.com');
    expect(rules.domainPattern[2].type, 'regex');
    expect(rules.domainPattern[2].pattern, 'a.com');

    expect(rules.checkDomain('abc.com'), true);
    expect(rules.checkDomain('1.com'), true);
    expect(rules.checkDomain('a1.com'), false);
    expect(rules.checkDomain('a.com'), true);
    expect(rules.checkDomain('1a.com'), true);
    expect(rules.checkDomain('1a2com'), true);

    // var doh2 = DnsOverHttps('https://doh.pub/dns-query');
    // var record = await doh2.lookupHttps('tsinghua.edu.cn');
    // record = await doh2.lookupHttps('sgu.edu.cn');
  });
}
