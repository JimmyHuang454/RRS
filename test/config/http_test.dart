import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';

import 'package:proxy/handler.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/utils/utils.dart';

void main() {
  test('buildInStream', () async {
    var f = File('./test/config/http_freedom.json');
    var config = jsonDecode(await f.readAsString());
    var listen = '127.0.0.1';
    var port = await getUnusedPort(InternetAddress(listen));
    config['inbounds']['HTTPIn']['setting']['port'] = port;
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
