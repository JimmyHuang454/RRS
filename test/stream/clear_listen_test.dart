import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:proxy/handler.dart';
import 'package:test/test.dart';

import 'package:proxy/utils/utils.dart';

void main() {
  var host = '127.0.0.1';

  test('dart clearListen', () async {
    //{{{
    var serverPort = await getUnusedPort(InternetAddress(host));

    var serverListen = await ServerSocket.bind(host, serverPort);

    var receiveTimes = 0;
    serverListen.listen((inClient) {
      late StreamSubscription streamSubscription;
      var fu = inClient.asBroadcastStream();
      streamSubscription = fu.listen((data) async {
        receiveTimes += 1;
        await streamSubscription.cancel();
        fu.listen((date2) async {
          receiveTimes += 1;
        });
      });
    });

    var c = await Socket.connect(host, serverPort);
    c.add([1]);
    await delay(1);
    expect(receiveTimes, 1);

    c.add([1]);
    await delay(2);
    expect(receiveTimes, 2);
  }); //}}}

  test('rrs clearListen', () async {
    //{{{
    var serverPort = await getUnusedPort(InternetAddress(host));

    var client = buildOutStream('jls', {});
    var server = buildInStream('jls', {});
    var serverListen = await server.bind(host, serverPort);

    var receiveTimes = 0;
    serverListen.listen((inClient) {
      inClient.listen((data) async {
        receiveTimes += 1;
        await inClient.clearListen();
        inClient.listen((date2) async {
          receiveTimes += 1;
        });
      });
    });

    var c = await client.connect(host, serverPort);
    c.add([1]);
    await delay(1);
    expect(receiveTimes, 1);

    c.add([1]);
    await delay(2);
    expect(receiveTimes, 2);
  }); //}}}
}
