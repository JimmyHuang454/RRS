import 'package:test/test.dart';
import 'dart:html';
import 'package:proxy/utils/utils.dart';

void main() {
  test('address', () {
    var res = Address('https://trojan-gfw.github.io/trojan/protocol');
    expect(res.address, 'https://trojan-gfw.github.io/trojan/protocol');
    expect(res.type, 'domain');
  });

  test('address', () async{
    var res = CustomStream<int>();
  });
}
