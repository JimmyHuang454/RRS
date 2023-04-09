import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/transport/server/tcp.dart';
import 'package:proxy/utils/utils.dart';

void main() {
  eventTest(ServerSocket serverSocket, String host, int port) async {
    //{{{
    var serverListenDone = false;
    serverSocket.listen(
      (inclient) async {
        inclient.listen((event) async {
          inclient.add(event);
          await delay(1);
          await inclient.close();
        }, onDone: () async {
          serverListenDone = true;
        });
      },
    );

    var clientListenClosed = false;
    var clientDone = false;
    var isClientReceived = false;
    var client = await Socket.connect(host, port);
    client.listen((event) {
      isClientReceived = true;
    }, onDone: () {
      clientListenClosed = true;
    });

    client.done.then((v) {
      clientDone = true;
    });

    expect(serverListenDone, false);
    expect(clientListenClosed, false);
    expect(clientDone, false);
    expect(isClientReceived, false);

    client.add([1]);
    await delay(2);
    expect(isClientReceived, true);
    expect(clientListenClosed, true);
    expect(clientDone, false);
    expect(serverListenDone, false);

    await client.close();
    await delay(2);
    expect(serverListenDone, true);
    expect(clientDone, true);
  } //}}}

  test('dart tcp', () async {
    //{{{
    var host = '127.0.0.1';
    var port = await getUnusedPort(InternetAddress(host));
    var server = await ServerSocket.bind(host, port);
    await eventTest(server, host, port);
  }); //}}}
}
