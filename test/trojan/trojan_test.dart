import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';

import 'package:proxy/handler.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/utils/utils.dart';
import 'package:json5/json5.dart';

void main() {
  test('trojan', () async {
    var f = File('./test/trojan/trojan.json');
    var config = JSON5.parse(await f.readAsString());
    var listen = '127.0.0.1';
    var port1 = await getUnusedPort(InternetAddress(listen));
    var port2 = await getUnusedPort(InternetAddress(listen));
    config['inbounds']['HTTPIn']['setting']['port'] = port1;
    config['inbounds']['TrojanIn']['setting']['port'] = port2;
    config['outbounds']['TrojanOut']['setting']['port'] = port2;
    entry(config);

    var client = TCPClient(config: {});
    await client.connect(listen, port1);

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
    await client.close();
    await Future.delayed(Duration(seconds: 2));
    expect(res.contains('Hello world'), true);
  });
}
