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
      s.listen((event) {}, onDone: () {
        s.close();
      });

      s.done.then(
        (value) {
          serverListenDone = true;
        },
      );
    });

    var client = await WebSocket.connect('ws://$host:$port');
    client.listen((event) {
      print(event);
    });

    client.done.then(
      (value) {
        print('client done.');
        clientClosed = true;
      },
    );

    client.add([1]);
    await delay(1);
    await client.close();
    await delay(2);
    expect(clientClosed, true);
    expect(serverListenDone, true);
  });
}
