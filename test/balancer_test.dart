import 'package:proxy/balance/balancer.dart';
import 'package:proxy/handler.dart';
import 'package:proxy/obj_list.dart';
import 'package:test/test.dart';

void main() {
  test('load balancer.', () async {
    expect(
        () async => Balancer(config: {
              'outbound': ['abc']
            }),
        throwsException);

    expect(
        () async => Balancer(config: {
              'outbound': ['']
            }),
        throwsException);

    expect(
        () async => Balancer(config: {
              'outbound': ['', 'abc']
            }),
        throwsException);

    entry({
      'outbounds': {
        'abc': {
          'protocol': 'trojan',
          'setting': {'address': '1', 'port': 1, 'password': '1'}
        }
      },
      'balance': {
        'abc': {'outbound': 'abc'}
      }
    });

    expect(balancerList.containsKey('abc'), true);
    expect(balancerList['abc']!.outbound.length, 1);
    expect(balancerList['abc']!.outbound[0].tag, 'abc');
    expect(
        () async => entry({
              'routes': {
                'abc': {
                  'rules': [
                    {'outbound': 'abc', 'balance': 'abc'}
                  ] as dynamic
                }
              }
            }),
        throwsException);

    entry({
      'routes': {
        'abc': {
          'rules': [
            {'balance': 'abc'}
          ] as dynamic
        }
      }
    });
    var rule1 = routeList['abc']!.rules[0];
    expect(rule1.balancer!.tag, 'abc');
    expect(rule1.balancer!.dispatch().tag, 'abc');
  });
}
