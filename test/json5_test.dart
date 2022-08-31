import 'package:test/test.dart';
import 'package:json5/json5.dart';

void main() {
  test('json5', () {
    var te = (JSON5.parse('{"test": 1 // 1lcba\n}') as Map<String, dynamic>);
    expect(te.containsKey('test'), true);

    te = (JSON5.parse('{"test": 1,"list": [1,"2",]}') as Map<String, dynamic>);
    expect(te.containsKey('test'), true);

    te = (JSON5.parse('{\'test\': 1,"list": [1,"2",]}') as Map<String, dynamic>);
    expect(te.containsKey('test'), true);
  });
}
