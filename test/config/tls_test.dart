import 'dart:convert';
import 'package:test/test.dart';

import 'package:proxy/transport/client/tcp.dart';

void main() {
  test('tls', () async {
    var client = TCPClient(config: {
      'tag': 'TCPClient_http',
      'tls': {'enabled': true}
    });
    await client.connect('uif02.xyz', 443);
    client.add('GET /test HTTP/1.1\r\nHost: uif02.xyz\r\n\r\n'.codeUnits);
    var res = '';
    client.listen(
      (event) {
        res = utf8.decode(event);
      },
    );
    await Future.delayed(Duration(seconds: 2));
    expect(res.contains('Hello world'), true);
  });
}
