import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';

import 'package:proxy/handler.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:json5/json5.dart';

void main() {
  test('http to http', () async {
    var f = File('./test/config/http_to_http.json');
    var config = JSON5.parse(await f.readAsString());
    var listen = '127.0.0.1';
    var port = config['inbounds']['HTTPIn1']['setting']['port'];
    entry(config);

    var client = TCPClient(config: {'tag': 'TCPClient_http'});
    await client.connect(listen, port);

    client.add('GET http://uif02.xyz/test HTTP/1.1\r\nHost: uif02.xyz\r\n\r\n'
        .codeUnits);

    var res = '';
    client.listen(
      (event) {
        res = utf8.decode(event);
        // print(res);
      },
    );
    await Future.delayed(Duration(seconds: 2));
    expect(res.contains('Hello world'), true);
  });
}
