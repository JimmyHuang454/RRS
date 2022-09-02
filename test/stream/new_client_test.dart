import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/transport/server/tcp.dart';
import 'package:proxy/utils/utils.dart';

void main() {
  test('tcp mux', () async {
    var host = '127.0.0.1';
    var port = await getUnusedPort(InternetAddress(host));
    var client = TCPClient2(config: {
      'mux': {'enabled': true}
    });
    var server = TCPServer(config: {});

    var msg = '1';
    bool serverClosed = false;
    bool clientClosed = false;
    await server.bind(host, port);
    server.listen((inClient) {
      inClient.listen((event) {
        print(event);
        expect(utf8.decode(event), msg);
      }, onDone: () async {
        clientClosed = true;
      });
    }, onDone: () async {
      serverClosed = true;
    });

    var rrssocket = await client.connect(host, port);

    rrssocket.add(msg.codeUnits);

    await Future.delayed(Duration(seconds: 2));

    await rrssocket.close();
    await server.close();
    await Future.delayed(Duration(seconds: 2));
    expect(clientClosed, true);
    expect(serverClosed, true);
  });
}
