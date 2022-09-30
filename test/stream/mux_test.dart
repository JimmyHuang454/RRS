import 'dart:convert';
import 'dart:io';

import 'package:quiver/collection.dart';
import 'package:proxy/transport/mux.dart';
import 'package:test/test.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/transport/server/tcp.dart';
import 'package:proxy/utils/utils.dart';

void main() {
  //test('tcp with no mux', () async {
  //  //{{{
  //  var host = '127.0.0.1';
  //  var port = await getUnusedPort(InternetAddress(host));
  //  var client = MuxClient(transportClient1: TCPClient2(config: {}));
  //  var bind = MuxServer(transportServer1: TCPServer2(config: {}));

  //  var msg = '1';
  //  bool serverReciveClosed = false;
  //  bool clientClosed = false;
  //  bool isRecieve = false;

  //  var server = await bind.bind(host, port);
  //  server.listen((inClient) {
  //    inClient.listen((event) {
  //      expect(utf8.decode(event), msg);
  //      inClient.add(event);
  //    }, onDone: () {
  //      clientClosed = true;
  //    });
  //  }, onDone: () {
  //    serverReciveClosed = true;
  //  });

  //  var socket2 = await client.connect(host, port);

  //  socket2.listen(
  //    (event) {
  //      expect(listsEqual(event, msg.codeUnits), true);
  //      isRecieve = true;
  //    },
  //  );

  //  socket2.add(msg.codeUnits);

  //  await Future.delayed(Duration(seconds: 2));

  //  await socket2.close();
  //  await server.close();
  //  await Future.delayed(Duration(seconds: 2));
  //  expect(clientClosed, true);
  //  expect(serverReciveClosed, true);
  //  expect(isRecieve, true);
  //}); //}}}

  test('tcp mux', () async {
    //{{{
    var host = '127.0.0.1';
    var port = await getUnusedPort(InternetAddress(host));
    var muxPWD = '123';
    var config = {
      'mux': {'enabled': true, 'password': muxPWD}
    };
    var client = MuxClient(transportClient1: TCPClient2(config: config));
    var bind = MuxServer(transportServer1: TCPServer2(config: config));

    var msg = '1'; // length == 1
    bool serverReciveClosed = false; // close signal from client.
    bool clientReciveClosed = false; // close signal from server.
    bool isRecieve = false;

    var server = await bind.bind(host, port);

    server.listen((inClient) {
      inClient.listen((event) {
        expect(utf8.decode(event), msg);
        inClient.add(event);
      }, onDone: () async {
        serverReciveClosed = true;
        await delay(2);
        inClient.close();
      });
    }, onDone: () {});

    var muxSocket = await client.connect(host, port);
    muxSocket.add(msg.codeUnits);

    muxSocket.listen((event) {
      expect(listsEqual(event, msg.codeUnits), true);
      isRecieve = true;
    }, onDone: () {
      clientReciveClosed = true;
    });

    client.mux.forEach(
      (key, value) {
        expect(value.length, 1);
      },
    );
    var isdone = false;
    muxSocket.done.then((value) {
      isdone = true;
    },);

    await delay(1);
    expect(isRecieve, true);

    muxSocket.close();
    await delay(1);
    expect(serverReciveClosed, true);
    expect(clientReciveClosed, false);
    expect(isdone, false);

    await delay(2);
    expect(clientReciveClosed, true);
    expect(isdone, true);

    client.clearEmpty();
    expect(client.mux.length, 0);

    return;
    //----------------------------------
    serverReciveClosed = false;
    clientReciveClosed = false;
    isRecieve = false;

    muxSocket = await client.connect(host, port);
    var muxSocket2 = await client.connect(host, port);
    expect(client.mux.length, 1);

    muxSocket.listen((event) {
      expect(listsEqual(event, msg.codeUnits), true);
      isRecieve = true;
    }, onDone: () {
      clientReciveClosed = true;
    });

    var clientReciveClosed2 = false;
    muxSocket2.listen((event) {
      print(event);
    }, onDone: () {
      clientReciveClosed2 = true;
    });

    muxSocket.add(msg.codeUnits);
    await delay(1);
    expect(isRecieve, true);
    expect(serverReciveClosed, false);
    expect(clientReciveClosed, false);
    expect(clientReciveClosed2, false);

    muxSocket.close();
    await delay(1);
    expect(serverReciveClosed, true);
    expect(clientReciveClosed, false);
    expect(clientReciveClosed2, false);

    await delay(2);
    expect(clientReciveClosed, true);
    expect(clientReciveClosed2, false);
  }); //}}}
}
