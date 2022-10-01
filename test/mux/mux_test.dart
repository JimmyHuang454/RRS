import 'dart:convert';
import 'dart:io';

import 'package:proxy/transport/client/tcp.dart';
import 'package:quiver/collection.dart';
import 'package:test/test.dart';
import 'package:proxy/handler.dart';

import 'package:proxy/utils/utils.dart';

void main() {
  test('mux test', () async {
    var f = File('./test/mux/mux_test.json');
    var config = jsonDecode(await f.readAsString());
    entry(config);

    var client = TCPClient2(config: {'tag': 'TCPClient_http'});
    var j = 0;
    var times = 10;
    for (var i = 0, len = times; i < len; ++i) {
      var so = await client.connect('127.0.0.1', 18080);
      so.add(buildHTTPProxyRequest('uif02.xyz'));
      so.listen(
        (event) {
          so.close();
        },
      );
      so.done.then(
        (value) {
          j += 1;
        },
      );
    }
    await delay(3);

    expect(j, times);
  });
}
