import 'dart:async';
import 'dart:io';
import 'package:async/async.dart';

import 'package:proxy/utils/utils.dart';
import 'package:test/test.dart';

void main() {
  test('temp test.', () async {
    var temp = Uri.parse('http://127.0.0.1');
    expect(temp.host, '127.0.0.1');

    temp = Uri.parse('127.0.0.1');
    expect(temp.host, '');

    temp = Uri.parse('www.abc.com');
    expect(temp.host, '');

    temp = Uri.parse('abc.com');
    expect(temp.host, '');

    temp = Uri.parse('abc');
    expect(temp.host, '');

    temp = Uri.parse('fuck://abc');
    expect(temp.host, 'abc');

    temp = Uri.parse('fuck://abc.cn');
    expect(temp.host, 'abc.cn');
  });
}
