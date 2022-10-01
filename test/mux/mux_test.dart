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

  test('mux test', () async {//{{{
    var f = File('./test/mux/mux_test.json');
    var config = jsonDecode(await f.readAsString());
    entry(config);
    var httpServer = await HttpServer.bind('127.0.0.1', 80);

    httpServer.forEach((HttpRequest request) {
      request.response.write('Hello, world!');
      request.response.close();
    });

    var client = TCPClient2(config: {'tag': 'TCPClient_http'});
    var j = 0;
    var r = 0;
    var d = 0;
    var times = 10;
    for (var i = 0, len = times; i < len; ++i) {
      var so = await client.connect('127.0.0.1', 18080);
      so.add(buildHTTPProxyRequest('127.0.0.1'));
      so.listen((event) {
        r += 1;
      }, onDone: () {
        d += 1;
      });

      so.done.then(
        (value) {
          j += 1;
        },
      );
      so.close();
      await delay(1);
    }
    await delay(3);

    expect(j, times);
    expect(d, times);
    expect(r, times);
  });//}}}
}
