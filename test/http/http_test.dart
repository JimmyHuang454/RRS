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
    var host = '127.0.0.1';
    var port1 = await getUnusedPort(InternetAddress(host));
    var serverPort = await getUnusedPort(InternetAddress(host));
    var domain = '$host:$serverPort';
    config['inbounds']['HTTPIn']['setting']['port'] = port1;
    entry(config);

    var httpServer = await ServerSocket.bind(host, serverPort);
    httpServer.listen(
      (event) {
        event.add('Hello world'.codeUnits);
        event.close();
      },
    );

    var client = TCPClient(config: {});
    var temp = await client.connect(host, port1);
    var times = 0;
    var clientClosed = false;
    temp.listen((data) {
      expect(utf8.decode(data).contains('Hello world'), true);
      times += 1;
    }, onDone: () {
      clientClosed = true;
    });
    temp.add(buildHTTPProxyRequest(domain));
    await delay(2);
    expect(clientClosed, true);
    expect(times, 1);

    // expect(temp.isClosed, true);
  });
}
