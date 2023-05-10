import 'dart:io';

import 'package:async/async.dart';
import 'package:test/test.dart';

import 'package:proxy/utils/utils.dart';

void main() {
  return;
  void feed(Socket client) async {
    client.listen((event) {
      devPrint(event);
    }, onDone: () {});

    for (var i = 0; i < 3; ++i) {
      client.add([i]);
      devPrint(i);
      await client.flush();
    }
  }

  test('stream use case.', () async {
    //{{{
    var host = '127.0.0.1';
    var serverPort = await getUnusedPort(InternetAddress(host));
    var serverPort2 = await getUnusedPort(InternetAddress(host));
    var httpServer = await ServerSocket.bind(host, serverPort);
    var httpServer2 = await ServerSocket.bind(host, serverPort);
    var clientClosed = false;
    httpServer.listen((event) async {
      event.addStream(event);
      event.listen((data) {
        devPrint(data);
      }, onDone: () {});
    });

    httpServer2.listen((event) async {
      event.listen((data) async {
        devPrint(data);
      }, onDone: () {});
    });

    var client = await Socket.connect(host, serverPort);

    feed(client);

    await delay(4);
    await client.close();
    await delay(1);
    expect(clientClosed, true);
  }); //}}}
}
