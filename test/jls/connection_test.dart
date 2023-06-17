import 'dart:io';

import 'package:proxy/handler.dart';
import 'package:proxy/utils/utils.dart';
import 'package:test/test.dart';

void main() {
  test('jls stream.', () async {
    var res = buildOutStream('jls', {
      'jls': {'enabled': true}
    });

  });
}
