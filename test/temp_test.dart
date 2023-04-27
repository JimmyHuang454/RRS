import 'dart:async';
import 'package:async/async.dart';

import 'package:proxy/utils/utils.dart';
import 'package:test/test.dart';

void main() {
  test('temp test.', () async {
    DateTime createdTime = DateTime.now();
    await delay(2);

    devPrint(DateTime.now().difference(createdTime));
  });
}
