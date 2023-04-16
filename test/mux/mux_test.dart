import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:proxy/handler.dart';

import 'package:proxy/utils/utils.dart';

void main() {

  test('mux test', () async {
    //{{{
    var f = File('./test/mux/mux_test.json');
    var config = jsonDecode(await f.readAsString());
    var host = '127.0.0.1';
    entry(config);
    var port2 = await getUnusedPort(InternetAddress(host));
    var httpServer = await ServerSocket.bind(host, port2);
    var tag = '111111111';
    httpServer.listen(
      (event) {
        event.add(tag.codeUnits);
        event.close();
      },
    );

    var times = 2;
    var clientList = {};
    var receiveList = {};
    var d = 0;
    for (var i = 0, len = times; i < len; ++i) {
      clientList[i] = await Socket.connect('127.0.0.1', 18080);
      clientList[i].listen((event) {
        receiveList[i] = true;
      }, onDone: () {
        d += 1;
      });
    }


    for (var i = 0, len = times; i < len; ++i) {
      clientList[i].add(buildHTTPProxyRequest('127.0.0.1:$port2'));
      await delay(2);
    }

    expect(receiveList.length, times);
    expect(d, times);
  }); //}}}
}
