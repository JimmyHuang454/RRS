import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';

import 'package:proxy/handler.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/utils/utils.dart';

void main() async {
  var config = await readConfigWithJson5('./test/http/http.json');
  var host = '127.0.0.1';
  var port1 = await getUnusedPort(InternetAddress(host));
  var port2 = await getUnusedPort(InternetAddress(host));
  var port3 = await getUnusedPort(InternetAddress(host));
  var serverPort = await getUnusedPort(InternetAddress(host));
  var domain = '$host:$serverPort';
  config['inbounds']['HTTPIn1']['setting']['port'] = port1;
  config['outbounds']['HTTPOut']['setting']['port'] = port1;
  config['inbounds']['HTTPIn2']['setting']['port'] = port2;
  config['inbounds']['HTTPIn3']['setting']['port'] = port3;
  entry(config);

  var httpServer = await ServerSocket.bind(host, serverPort);
  var msg = 'Hello world'.codeUnits;
  httpServer.listen(
    (event) {
      event.add(msg);
      event.close();
    },
  );

  test('HTTPIn1 -> freedom', () async {
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
  });

  test('HTTPIn2 -> HTTPOut -> HTTPIn1 -> freedom', () async {
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
  });

  test('HTTPIn1 -> block', () async {
    var client = TCPClient(config: {});
    var temp = await client.connect(host, port3);
    var clientClosed = false;
    var res = false;
    temp.listen((data) {
      res = true;
    }, onDone: () {
      clientClosed = true;
    });
    temp.add(buildHTTPProxyRequest(domain));
    await delay(2);
    expect(clientClosed, true);
    expect(res, false);
  });
}
