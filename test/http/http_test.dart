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
    (event) async {
      event.add(msg);
      await event.flush();
      await event.close();
    },
  );

  test('HTTPIn1 -> freedom', () async {
    var client = TCPClient(config: {});
    var temp = await client.connect(host, port1);
    var times = 0;
    var clientClosed = false;
    temp.listen((data) async {
      expect(utf8.decode(data).contains('Hello world'), true);
      times += 1;
    }, onDone: () async {
      clientClosed = true;
    });
    temp.add(buildHTTPProxyRequest(domain));
    await delay(2);
    expect(clientClosed, true);
    expect(times, 1);
  });

  test('HTTPIn2 -> HTTPOut -> HTTPIn1 -> freedom', () async {
    var client = TCPClient(config: {});
    var temp = await client.connect(host, port2);
    var times = 0;
    var clientClosed = false;
    temp.listen((data) async {
      expect(utf8.decode(data).contains('Hello world'), true);
      times += 1;
    }, onDone: () async {
      clientClosed = true;
    });

    await temp.add(buildHTTPProxyRequest(domain));
    await delay(1);
    expect(clientClosed, true);
    expect(times, 1);
  });

  test('HTTPIn1 -> block', () async {
    var client = TCPClient(config: {});
    var temp = await client.connect(host, port3);
    var clientClosed = false;
    var res = false;
    temp.listen((data) async {
      res = true;
    }, onDone: () async {
      clientClosed = true;
    });
    await temp.add(buildHTTPProxyRequest(domain));
    await delay(1);
    expect(clientClosed, true);
    expect(res, false);
  });

  test('HTTPIn close correctly.', () async {
    var client = TCPClient(config: {});
    var serverPort2 = await getUnusedPort(InternetAddress(host));
    var httpServer = await ServerSocket.bind(host, serverPort2);
    var domain2 = '$host:$serverPort2';
    httpServer.listen(
      (event) async {
        event.listen(
          (event) {
            print(event);
          },
        );

        for (var i = 0; i < 1; ++i) {
          event.add([i]);
          await delay(1);
        }
        event.close();
      },
    );
  });
}
