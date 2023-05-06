import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';

import 'package:proxy/handler.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/utils/utils.dart';

void main() {
  test('http', () async {
    var config = await readConfigWithJson5('./test/socks5/socks5.json');
    var host = '127.0.0.1';
    var port1 = await getUnusedPort(InternetAddress(host));
    var port2 = await getUnusedPort(InternetAddress(host));
    var serverPort = await getUnusedPort(InternetAddress(host));
    var domain = '$host:$serverPort';
    config['inbounds']['httpInbound']['setting']['port'] = port1;
    config['inbounds']['socks5Inbound']['setting']['port'] = port2;
    config['outbounds']['socks5Out']['setting']['port'] = port2;
    entry(config);

    var httpServer = await ServerSocket.bind(host, serverPort);
    var msg = 'Hello world'.codeUnits;
    httpServer.listen(
      (event) {
        event.add(msg);
        event.close();
      },
    );

    // httpInbound -> socks5Out -> socks5Inbound -> freedom
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
