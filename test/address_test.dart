import 'package:test/test.dart';
import 'package:proxy/utils/utils.dart';

void main() {
  test('address', () {
    var res = Address('https://trojan-gfw.github.io/trojan/protocol');
    expect(res.address, 'https://trojan-gfw.github.io/trojan/protocol');
    expect(res.type, 'domain');
  });
}
