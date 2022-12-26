import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/transport/server/tcp.dart';
import 'package:proxy/utils/utils.dart';

void main() {
  // test('tcp', () async {//{{{
  //   var host = '127.0.0.1';
  //   var port = await getUnusedPort(InternetAddress(host));

  //   var msg = 'fuck you';
  //   bool serverClosed = false;
  //   bool clientClosed = false;
  //   var server = TCPServer(config: {});
  //   await server.bind(host, port);

  //   server.listen((inClient) {
  //     inClient.listen((event) {
  //       expect(utf8.decode(event), msg);
  //     }, onDone: () async {
  //       clientClosed = true;
  //     });
  //   }, onDone: () async {
  //     serverClosed = true;
  //   });

  //   var client = await TCPClient(config: {}).connect(host, port);

  //   client.add(msg.codeUnits);

  //   await Future.delayed(Duration(seconds: 2));

  //   await client.close();
  //   await server.close();
  //   await Future.delayed(Duration(seconds: 2));
  //   expect(clientClosed, true);
  //   expect(serverClosed, true);
  // });//}}}

  test('normal tcp', () async {
    var host = '127.0.0.1';
    var port = await getUnusedPort(InternetAddress(host));
    var listenDone = false;
    var clientDone = false;
    var serverListenDone = false;

    var server = await ServerSocket.bind(host, port);
    server.listen(
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

    var isget = false;
    var client = await Socket.connect(host, port);
    client.listen((event) {
      isget = true;
    }, onDone: () {
      listenDone = true;
    });

    client.done.then((v) {
      clientDone = true;
    });

    client.add([1]);
    await delay(1);
    expect(isget, true);

    await client.close();
    await delay(2);
    expect(listenDone, true);
    expect(serverListenDone, true);
    expect(clientDone, true);
  });
}
