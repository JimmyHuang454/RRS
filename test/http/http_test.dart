import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';

import 'package:proxy/handler.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/utils/utils.dart';

void main() {
  test('http', () async {
    var f = File('./test/http/http_freedom.json');
    var config = jsonDecode(await f.readAsString());
    var listen = '127.0.0.1';
    var port1 = await getUnusedPort(InternetAddress(listen));
    var port2 = await getUnusedPort(InternetAddress(listen));
    config['inbounds']['HTTPIn']['setting']['port'] = port1;
    config['inbounds']['HTTPIn_block']['setting']['port'] = port2;
    entry(config);

    var client = TCPClient(config: {'tag': 'TCPClient_http'});
    await client.connect(listen, port1);
    client.add('GET http://uif02.xyz/test HTTP/1.1\r\nHost: uif02.xyz\r\n\r\n'
        .codeUnits);
    var res = '';
    client.listen((event) {
      res = utf8.decode(event);
      // print(res);
    });
    await Future.delayed(Duration(seconds: 2));
    expect(res.contains('Hello world'), true);

    client = TCPClient(config: {'tag': 'TCPClient_http'});
    await client.connect(listen, port2);
    client.add('GET http://uif02.xyz/test HTTP/1.1\r\nHost: uif02.xyz\r\n\r\n'
        .codeUnits);
    res = '';
    client.listen((event) {
      res = utf8.decode(event);
      // print(res);
    });
    await Future.delayed(Duration(seconds: 2));
    expect(res, '');
  });
}
