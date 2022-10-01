import 'dart:convert';
import 'dart:io';

import 'package:proxy/transport/client/tcp.dart';
import 'package:quiver/collection.dart';
import 'package:test/test.dart';
import 'package:proxy/handler.dart';

import 'package:proxy/utils/utils.dart';

void main() {
  // test('normal http', () async {//{{{
  //   var host = '127.0.0.1';
  //   var httpServer = await HttpServer.bind(host, 8000);

  //   httpServer.forEach((HttpRequest request) {
  //     request.response.write('Hello, world!');
  //     request.response.close();
  //   });

  //   var client = await Socket.connect(host, 8000);
  //   client.listen((event) {
  //     print(utf8.decode(event));
  //   }, onDone: () {
  //     print('done');
  //   });

  //   client.add(buildHTTPProxyRequest('127.0.0.1'));
  //   // await delay(3);
  // });//}}}

  test('mux test', () async {
    //{{{
    var f = File('./test/mux/mux_test.json');
    var config = jsonDecode(await f.readAsString());
    entry(config);
    var httpServer = await HttpServer.bind('127.0.0.1', 80);

    var tag = '111111111';

    httpServer.forEach((HttpRequest request) {
      request.response.write(tag);
      request.response.close();
    });

    var client = TCPClient2(config: {'tag': 'TCPClient_http'});
    var times = 100;
    var clientList = {};
    var receiveList = {};
    for (var i = 0, len = times; i < len; ++i) {
      clientList[i] = await client.connect('127.0.0.1', 18080);
      clientList[i].listen((event) {
        // expect(utf8.decode(event).contains(tag), true);
        receiveList[i] = true;
      }, onDone: () {});
    }
    await delay(1);

    for (var i = 0, len = times; i < len; ++i) {
      clientList[i].add(buildHTTPProxyRequest('127.0.0.1'));
    }
    await delay(2);

    expect(receiveList.length, times);
  }); //}}}
}
