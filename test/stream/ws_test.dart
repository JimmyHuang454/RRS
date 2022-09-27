import 'dart:io';

import 'package:test/test.dart';
import 'package:proxy/utils/utils.dart';

void main() {
  test('normal ws', () async {
    var host = '127.0.0.1';
    var port = await getUnusedPort(InternetAddress(host));
    var httpServer = await HttpServer.bind(host, port);

    var serverListenDone = false;
    var clientClosed = false;

    httpServer.listen((httpClient) async {
      var s = await WebSocketTransformer.upgrade(httpClient);
      s.listen((event) {
        print(event);
        s.close();
        print('closed');
      }, onDone: () async {
        serverListenDone = true;
        print('server done.');
      });
    });

    var client = await WebSocket.connect('ws://$host:$port');
    client.listen((event) {}, onDone: () {
      clientClosed = true;
    });

    client.add([1]);
    await delay(1);
    expect(clientClosed, true);
    // expect(serverListenDone, false);
    client.add([2]);
    await delay(3);
    await client.close();
  });
}
