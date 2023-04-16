import 'package:test/test.dart';
import 'package:proxy/route/ip_cidr.dart';

void main() {
  test('test ip CIDR.', () {
    var obj = CIDRIPv4();
    expect(obj.init('127.0.0.1'), false);
    expect(obj.init('127.0.0.1//23'), false);
    expect(obj.init('127.0/0.1'), false);
    expect(obj.init('127.0.0.1/'), false);
    expect(obj.init('127.0.0.1/888'), false);
    expect(obj.init('127.0.0.1/33'), false);
    expect(obj.init('127.0.0/8'), false);
    expect(obj.init('127.0.0.1.2/8'), false);
    expect(obj.init('127.0.0/8'), false);
    expect(obj.init('127.0../8'), false);
    expect(obj.init('127.0.0.1.2...../8'), false);
    expect(obj.init('/8'), false);
    expect(obj.init('.../8'), false);
    expect(obj.init('..../8'), false);
    expect(obj.init('..../'), false);
    expect(obj.init('....'), false);
    expect(obj.init('...1./3'), false);

    expect(obj.init('127.0.0.1/32'), true);
    expect(obj.init('127.0.0.1/0'), false);

    expect(obj.parse('255.1.2.3/8'), int.parse('1' * 8 + '0' * 24, radix: 2));
    expect(obj.parse('255.255.255.255/32'), int.parse('1' * 32, radix: 2));
    expect(obj.parse('255.255.255.255/0'), 0);

    obj.init('255.1.2.3/8');
    expect(obj.matchByString('255.0.0.0/8'), true);
    expect(obj.matchByString('254.1.2.3/7'), true);
    expect(obj.matchByString('255.0.0.0/1'), true);
    expect(obj.matchByString('251.0.0.0/8'), false);
    expect(obj.matchByString('10.0.0.0/8'), false);

    obj.init('192.168.1.2/24');
    expect(obj.matchByString('192.168.0.0/16'), true);
    expect(obj.matchByString('92.168.0.0/16'), false);
    expect(obj.include('192.168.0.0'), false);
    expect(obj.include('192.168.2.0'), false);
    expect(obj.include('192.168.1.0'), true);
  });
}
