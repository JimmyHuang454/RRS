import 'dart:io';

import 'package:proxy/route/route.dart';
import 'package:test/test.dart';

import 'package:proxy/handler.dart';
import 'package:proxy/obj_list.dart';
import 'package:quiver/pattern.dart';

Future<void> routeTest(Route obj) async {
  expect(obj.rules.length, 1);

  var rule = obj.rules[0];
  expect(rule.ipPattern.isNotEmpty, true);
  expect(rule.ipPattern[0].type, 'full');
  expect(rule.ipPattern[1].type, 'cidr');
  expect(rule.ipPattern[2].type, 'mmdb');
  expect(rule.ipPattern[2].pattern, 'CN');

  expect(await rule.ipPattern[0].match2('192.168.200.84'), true);
  expect(await rule.ipPattern[0].match2('192.168.200.83'), false);

  expect(await rule.ipPattern[1].match2('192.168.1.0'), true);
  expect(await rule.ipPattern[1].match2('192.168.1.2'), true);
  expect(await rule.ipPattern[1].match2('192.168.0.0'), false);
  expect(await rule.ipPattern[1].match2('192.169.0.0'), false);

  expect(await rule.ipPattern[2].match2('110.242.68.66'), true); // CN IP
  expect(await rule.ipPattern[2].match2('199.59.148.247'), false); // not CN
  expect(await rule.ipPattern[2].match2('1.1.1.1'), false); // not CN
  var ip = await rule.dns!.resolve2('baidu.com');

  expect(await rule.matchIP(ip), true);
}

void main() {
  var dbFile = File('./bin/Country.mmdb');

  test('route match', () async {
    entry({
      'outbounds': {
        'out1': {
          'setting': {
            'address': '1',
            'port': 1,
            'password': '1',
          },
          'outStream': 'tcp'
        }
      },
    });

    buildRoute('test_route', {
      "rules": [
        {
          "user": ["1"],
          "domain": ["bc.com", "full:1.com", "regex:a.com", "regex:.*.cn"],
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

    expect(await rules.matchDomain('abc.com'), true);
    expect(await rules.matchDomain('1.com'), true);
    expect(await rules.matchDomain('2.com'), false);
    expect(await rules.matchDomain('a1.com'), false);
    expect(await rules.matchDomain('a.com'), true);
    expect(await rules.matchDomain('1a.com'), true);
    expect(await rules.matchDomain('1a2com'), true);

    expect(await rules.matchDomain('abc1cn'), true);
    expect(await rules.matchDomain('a.b.c.cn'), true);
    expect(await rules.matchDomain('a.b.c.cnn'), true);
  });

  test('regex', () async {
    var re = RegExp('.baidu.com');
    expect(re.hasMatch('www.baidu.com'), true);
    expect(re.hasMatch('abaidu.com'), true);
    expect(re.hasMatch('baiducom'), false);
    expect(re.hasMatch('.baiducom'), false);
    expect(re.hasMatch('baidu1com'), false);
    expect(re.hasMatch('.baidu1com'), true);
    expect(re.hasMatch('.baidu1.com'), false);
    expect(re.hasMatch('.baidu2com'), true);

    re = RegExp('baidu.*com');
    expect(re.hasMatch('www.baidu.com'), true);
    expect(re.hasMatch('abaidu.com'), true);
    expect(re.hasMatch('abaidu1com'), true);
    expect(re.hasMatch('abaidu12com'), true);

    re = RegExp('baidu.com');
    expect(re.hasMatch('www.baidu.com'), true);
    expect(re.hasMatch('baiducom'), false);
    expect(re.hasMatch('baidu1com'), true);

    re = RegExp(r'baidu\.com');
    expect(re.hasMatch('www.baidu.com'), true);
    expect(re.hasMatch('baiducom'), false);
    expect(re.hasMatch('baidu1com'), false);
    expect(re.hasMatch('2baidu1com'), false);

    var res2 = escapeRegex('baidu.com');
    re = RegExp(res2);
    expect(re.hasMatch('www.baidu.com'), true);
    expect(re.hasMatch('baiducom'), false);
    expect(re.hasMatch('baidu1com'), false);
    expect(re.hasMatch('2baidu1com'), false);

    res2 = escapeRegex('baidu.com');
    re = RegExp(res2);
    expect(re.hasMatch('www.baidu.com'), true);
    expect(re.hasMatch('baiducom'), false);
    expect(re.hasMatch('baidu1com'), false);
    expect(re.hasMatch('2baidu1com'), false);
  });

  test('ip route match', () async {
    entry({
      'outbounds': {
        'out1': {
          'setting': {
            'address': '1',
            'port': 1,
            'password': '1',
          },
          'outStream': 'tcp'
        }
      }
    });

    buildData('ipdb', {
      "geoip": {"type": "mmdb", "path": dbFile.path}
    });

    buildRoute('test_route', {
      "rules": [
        {
          "ip": [
            '192.168.200.84',
            '192.168.1.2/24',
            {'ipdb': 'geoip', 'type': 'CN'}
          ],
          "outbound": "out1"
        }
      ]
    });

    buildRoute('test_route_cached', {
      "rules": [
        {
          "ip": [
            '192.168.200.84',
            '192.168.1.2/24',
            {'ipdb': 'geoip', 'type': 'CN'}
          ],
          "outbound": "out1"
        }
      ],
      "cache": {'enable': true}
    });

    expect(routeList.containsKey('test_route'), true);

    await routeTest(routeList['test_route']!);
    await routeTest(routeList['test_route_cached']!);
  });
}
