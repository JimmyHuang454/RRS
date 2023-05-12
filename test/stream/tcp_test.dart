import 'dart:io';

import 'package:test/test.dart';

import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/transport/server/tcp.dart';
import 'package:proxy/utils/utils.dart';

class ServerBind {
  Future<ServerSocket> bind(dynamic host, dynamic port) async {
    return ServerSocket.bind(host, port);
  }
}

class ClientConnect {
  Future<Socket> connect(dynamic host, dynamic port) async {
    return Socket.connect(host, port);
  }
}

var serverBind = ServerBind();
var clientConnect = ClientConnect();

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
        await inClient.close();
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
    client.listen((event) async {
      isClientReceived = true;
    }, onDone: () async {
      clientListenClosed = true;
    });

    client.done.then((v) async {
      clientDone = true;
    });

    await delay(1);

    expect(serverListenDone, false);
    expect(serverClosed, false);
    expect(isClientReceived, false);
    expect(clientListenClosed, false);
    expect(clientDone, false);

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

  test('dart tcp client and dart tcp server.', () async {
    //{{{
    await eventTest(serverBind, clientConnect);
  }); //}}}

  test('RRS tcp client and dart tcp server.', () async {
    //{{{
    await eventTest(serverBind, TCPClient(config: {}));
  }); //}}}

  test('RRS tcp and RRS tcp server.', () async {
    //{{{
    await eventTest(TCPServer(config: {}), TCPClient(config: {}));
  }); //}}}
}
