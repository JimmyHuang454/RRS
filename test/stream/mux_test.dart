import 'dart:convert';
import 'dart:io';

import 'package:proxy/transport/mux.dart';
import 'package:test/test.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/transport/server/tcp.dart';
import 'package:proxy/utils/utils.dart';

void main() {
  test('tcp with no mux', () async {
    var host = '127.0.0.1';
    var port = await getUnusedPort(InternetAddress(host));
    var client = MuxClient(transportClient1: TCPClient2(config: {}));
    var bind = MuxServer(transportServer1: TCPServer2(config: {}));

    var msg = '1';
    bool serverClosed = false;
    bool clientClosed = false;
    bool isRecieve = false;

    var server = await bind.bind(host, port);
    server.listen((inClient) {
      inClient.listen((event) {
        expect(utf8.decode(event), msg);
        isRecieve = true;
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
    expect(isRecieve, true);
  });

  test('tcp mux', () async {
    var host = '127.0.0.1';
    var port = await getUnusedPort(InternetAddress(host));
    var temp = {
      'mux': {'enabled': true}
    };
    var client = MuxClient(transportClient1: TCPClient2(config: temp));
    var bind = MuxServer(transportServer1: TCPServer2(config: temp));

    var msg = '1';
    bool serverClosed = false;
    bool clientClosed = false;
    bool isRecieve = false;

    var server = await bind.bind(host, port);
    server.listen((inClient) {
      inClient.listen((event) {
        expect(utf8.decode(event), msg);
        isRecieve = true;
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
    expect(isRecieve, true);
  });
}
