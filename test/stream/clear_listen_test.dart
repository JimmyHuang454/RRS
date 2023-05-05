import 'dart:io';

import 'package:test/test.dart';

import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/utils/utils.dart';

void main() {
  test('dart listen twice.', () async {
    //{{{
    var host = '127.0.0.1';
    var port1 = await getUnusedPort(InternetAddress(host));
    var httpServer = await ServerSocket.bind(host, port1);
    var msg = 'Hello world'.codeUnits;
    httpServer.listen(
      (event) {
        event.add(msg);
      },
    );
    var con = await Socket.connect(host, port1);
    var isReceive = false;
    var listen = con.listen(
      (event) {
        isReceive = true;
      },
    );
    con.add([1]);
    await delay(2);
    expect(isReceive, true);

    await listen.cancel();

    isReceive = false;
    con.listen(
      (event) {
        isReceive = true;
      },
    );
    con.add([1]);
    await delay(2);
    expect(isReceive, false);
  }); //}}}

  test('RRS listen twice.', () async {
    //{{{
    var host = '127.0.0.1';
    var port1 = await getUnusedPort(InternetAddress(host));
    var httpServer = await ServerSocket.bind(host, port1);
    var msg = 'Hello world'.codeUnits;
    httpServer.listen(
      (event) {
        event.add(msg);
      },
    );
    var client = TCPClient(config: {});
    var con = await client.connect(host, port1);
    var isReceive = false;
    con.listen(
      (event) {
        isReceive = true;
      },
    );
    con.add([1]);
    await delay(2);
    expect(isReceive, true);

    await con.clearListen();

    isReceive = false;
    con.listen(
      (event) {
        isReceive = true;
      },
    );
    con.add([1]);
    await delay(2);
    expect(isReceive, true);
  }); //}}}
}
