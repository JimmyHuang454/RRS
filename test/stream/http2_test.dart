import 'dart:convert';

import 'package:proxy/handler.dart';
import 'package:proxy/utils/utils.dart';

import 'package:test/test.dart';

Map<String, Map<String, dynamic>> liveConnection = {};

void main() {
  test('http2', () async {
    var host = '127.0.0.1';
    var port = 7767;
    var server = buildInStream('s', {
      'protocol': 'h2',
      'setting': {'path': 'abc'}
    });
    var s = await server.bind(host, port);

    s.listen(
      (event) {
        event.listen(
          (data) {
            devPrint(data);
          },
        );
        event.add(utf8.encode('fuck'));
        devPrint('connected');
        event.close();
      },
    );

    var client = buildOutStream('c', {
      'protocol': 'h2',
      'setting': {'path': 'abc'}
    });

    var c = await client.connect(host, port);
    c.add('fuck'.codeUnits);
    await delay(3);
  });
}
