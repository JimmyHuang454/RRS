import 'dart:io';

import 'package:test/test.dart';
import 'package:proxy/utils/utils.dart';
import 'package:proxy/transport/server/ws.dart';
import 'package:proxy/transport/client/ws.dart';

void main() {
  eventTest(dynamic serverConfig, dynamic clientConfig) async {
    //{{{
    var host = '127.0.0.1';
    var port = await getUnusedPort(InternetAddress(host));

    var serverListenDone = false;
    var serverClosed = false;
    var server = await serverConfig.bind(host, port);

    server.listen((inClient) async {
      inClient.listen((event) async {
        inClient.add(event);
        await delay(1);
        inClient.close();
      }, onDone: () async {
        serverListenDone = true;
      });
    }, onDone: () {
      serverClosed = true;
    });

    var clientListenClosed = false;
    var clientDone = false;
    var isClientReceived = false;

    var client = await clientConfig.connect(host, port);
    client.listen((event) {
      isClientReceived = true;
    }, onDone: () {
      clientListenClosed = true;
    });

    client.done.then((v) {
      clientDone = true;
    });

    expect(serverListenDone, false);
    expect(isClientReceived, false);
    expect(clientListenClosed, false);
    expect(clientDone, false);
    expect(serverClosed, false);

    client.add([1]);
    await delay(2);
    expect(isClientReceived, true);
    expect(clientListenClosed, true);
    expect(clientDone, false);
    expect(serverListenDone, false);
    expect(serverClosed, false);

    await client.close();
    await delay(2);
    expect(serverListenDone, true);
    expect(clientDone, true);
    expect(serverClosed, false);

    await server.close();
    await delay(1);
    expect(serverClosed, true);
  } //}}}

  test('RRS ws and RRS ws server. With path.', () async {
    //{{{
    var path = '';
    var server = WSServer(config: {
      'setting': {'path': path}
    });

    var client = WSClient(config: {
      'setting': {'path': path}
    });
    await eventTest(server, client);
  }); //}}}
}
