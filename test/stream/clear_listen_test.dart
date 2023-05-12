import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:test/test.dart';

import 'package:proxy/utils/utils.dart';

void main() async {
  var host = '127.0.0.1';
  var serverPort = await getUnusedPort(InternetAddress(host));
  var serverPort2 = await getUnusedPort(InternetAddress(host));
  var httpServer = await ServerSocket.bind(host, serverPort);
  var httpServer2 = await ServerSocket.bind(host, serverPort2);

  httpServer.listen((event) async {
    var tun = await Socket.connect(host, serverPort2);
    late StreamSubscription sub;
    sub = event.listen((data) async {
      sub.pause();
      print('${data[0]} start');
      tun.add(data);
      await delay(2);
      await tun.flush();
      print('${data[0]} end');
      sub.resume();
    });
  });

  httpServer2.listen((event) async {
    event.listen((data) async {
      devPrint(data);
    }, onDone: () {});
  });

  Future<void> feed(Socket client) async {
    client.listen((event) async {
      // devPrint(event);
    }, onDone: () {});

    for (var i = 0; i < 10; ++i) {
      client.add([i]);
      print('sended $i');
      await client.flush();
      await delay(1);
    }
  }

  test('stream use case.', () async {
    //{{{

    var client = await Socket.connect(host, serverPort);

    await feed(client);
  }); //}}}
}
