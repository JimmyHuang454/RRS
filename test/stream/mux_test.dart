import 'dart:convert';
import 'dart:io';

import 'package:quiver/collection.dart';
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
        inClient.add(event);
      }, onDone: () async {
        clientClosed = true;
      });
    }, onDone: () async {
      serverClosed = true;
    });

    var rrssocket = await client.connect(host, port);

    rrssocket.listen(
      (event) {
        expect(listsEqual(event, msg.codeUnits), true);
        isRecieve = true;
      },
    );

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
    var port2 = await getUnusedPort(InternetAddress(host));
    var muxPWD = '123';
    var temp = {
      'mux': {'enabled': true, 'password': muxPWD}
    };
    var client = MuxClient(transportClient1: TCPClient2(config: temp));
    var bind = MuxServer(transportServer1: TCPServer2(config: temp));
    var bind2 = TCPServer2(config: temp);

    var msg = '1';
    bool serverClosed = false;
    bool clientClosed = false;
    bool isRecieve = false;

    bool serverClosed2 = false;
    bool clientClosed2 = false;
    bool isRecieve2 = false;

    var server = await bind.bind(host, port);
    var server2 = await bind2.bind(host, port2);
    server.listen((inClient) {
      inClient.listen((event) {
        expect(utf8.decode(event), msg);
        inClient.add(event);
      }, onDone: () async {
        clientClosed = true;
      });
    }, onDone: () async {
      serverClosed = true;
    });

    server2.listen((inClient) {
      inClient.listen((event) {
        if (isRecieve2) {
          var temp = [1, 0, 0, 0, 0, 0, 0, 0, 0];
          expect(listsEqual(temp, event), true);
        } else {
          var temp = [1, 0, 0, 0, 0, 0, 0, 0, 1];
          temp += msg.codeUnits;
          expect(listsEqual(temp, event), true);
          isRecieve2 = true;
        }
      }, onDone: () async {
        clientClosed2 = true;
      });
    }, onDone: () async {
      serverClosed2 = true;
    });

    var rrssocket = await client.connect(host, port);
    rrssocket.add(msg.codeUnits);

    rrssocket.listen(
      (event) {
        expect(listsEqual(event, msg.codeUnits), true);
        isRecieve = true;
      },
    );

    var rrssocket2 = await client.connect(host, port2);
    rrssocket2.add(msg.codeUnits);

    await Future.delayed(Duration(seconds: 2));

    expect(client.mux.length, 2);
    client.mux.forEach(
      (key, value) {
        expect(value.length, 1);
      },
    );

    await rrssocket.close();
    client.clearEmpty();
    expect(client.mux.length, 1);
    client.mux.forEach(
      (key, value) {
        expect(value.length, 1);
        value.forEach(
          (key2, value2) {
            expect(value2.usingList.length, 1);
          },
        );
      },
    );

    await server.close();

    await rrssocket2.close();
    client.clearEmpty();
    expect(client.mux.length, 0);

    await Future.delayed(Duration(seconds: 2));
    expect(clientClosed, true);
    expect(serverClosed, true);
    expect(isRecieve, true);

    expect(clientClosed2, true);
    expect(serverClosed2, false);
    expect(isRecieve2, true);
  });
}
