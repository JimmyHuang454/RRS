import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';

import 'package:proxy/handler.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/utils/utils.dart';
import 'package:json5/json5.dart';

void main() {
  test('trojan', () async {
    return;
    var f = File('./test/trojan/trojan.json');
    var config = JSON5.parse(await f.readAsString());
    var host = '127.0.0.1';
    var port1 = await getUnusedPort(InternetAddress(host));
    var port2 = await getUnusedPort(InternetAddress(host));
    var port3 = await getUnusedPort(InternetAddress(host));
    var port4 = await getUnusedPort(InternetAddress(host));
    var port5 = await getUnusedPort(InternetAddress(host));
    var domain = '$host:$port4';
    config['inbounds']['HTTPIn']['setting']['port'] = port1;
    config['inbounds']['HTTPIn_ws']['setting']['port'] = port5;
    config['inbounds']['TrojanIn']['setting']['port'] = port2;
    config['inbounds']['TrojanIn_ws']['setting']['port'] = port3;
    config['outbounds']['TrojanOut']['setting']['port'] = port2;
    config['outbounds']['TrojanOut_ws']['setting']['port'] = port3;
    entry(config);

    var httpServer = await ServerSocket.bind(host, port4);
    httpServer.listen(
      (event) {
        event.add('Hello world'.codeUnits);
        event.close();
      },
    );

    var client = TCPClient(config: {});
    var times = 10;
    var times2 = 0;
    for (var i = 0, len = times; i < len; ++i) {
      var temp = await client.connect(host, port1);
      temp.add(buildHTTPProxyRequest(domain));
      temp.listen(
        (data) {
          expect(utf8.decode(data).contains('Hello world'), true);
          times2 += 1;
        },
      );
    }
    await delay(2);
    // expect(times2, times);

    times2 = 0;
    for (var i = 0, len = times; i < len; ++i) {
      var temp = await client.connect(host, port5);
      temp.add(buildHTTPProxyRequest(domain));
      temp.listen(
        (data) {
          expect(utf8.decode(data).contains('Hello world'), true);
          times2 += 1;
        },
      );
    }
    await delay(2);
    expect(times2, times);

  });
}
