import 'package:test/test.dart';
import 'dart:io';

void main() {
  test('address', () {
    var res = InternetAddress('https://trojan-gfw.github.io/trojan/protocol');
    expect(res.address, 'd');
  });
}
