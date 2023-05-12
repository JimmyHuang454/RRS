import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/transport/server/tcp.dart';
import 'package:proxy/utils/utils.dart';

void main() async {
  var host = '127.0.0.1';
  var serverPort = await getUnusedPort(InternetAddress(host));
  var httpServer = await ServerSocket.bind(host, serverPort);
  var domain = '$host:$serverPort';
  httpServer.listen(
    (event) async {
      event.listen(
        (event) {
          // print(event);
        },
      );

      for (var i = 0; i < 3; ++i) {
        event.add([i]);
        await event.flush();
        await delay(1);
      }
      event.close();
    },
  );
  test('dart use case.', () async {
    //{{{
    var client = TCPClient(config: {});
    var temp = await client.connect(host, serverPort);
    var clientClosed = false;

    late StreamSubscription sub;

    temp.listen((data) async {
      print(data);
      await delay(2);
      print(data);
    }, onDone: () async {
      devPrint('closed');
      clientClosed = true;
    });

    await temp.add(buildHTTPProxyRequest(domain));
    await delay(5);

    await temp.close();
    await temp.done;
    expect(clientClosed, true);
  }); //}}}
}
