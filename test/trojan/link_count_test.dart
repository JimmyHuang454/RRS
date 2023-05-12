import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:proxy/obj_list.dart';
import 'package:proxy/transport/server/tcp.dart';
import 'package:test/test.dart';

import 'package:proxy/handler.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/utils/utils.dart';
import 'package:json5/json5.dart';

void main() {
  test('trojan', () async {
    var f = File('./test/trojan/trojan.json');
    var config = JSON5.parse(await f.readAsString());
    var host = '127.0.0.1';
    var port1 = await getUnusedPort(InternetAddress(host));
    var port2 = await getUnusedPort(InternetAddress(host));
    var port3 = await getUnusedPort(InternetAddress(host));
    var domain = '$host:$port3';
    config['inbounds']['HTTPIn']['setting']['port'] = port1;
    config['inbounds']['TrojanIn']['setting']['port'] = port2;
    config['outbounds']['TrojanOut']['setting']['port'] = port2;
    entry(config);

    var server = TCPServer(config: {});
    var httpServer = await server.bind(host, port3);
    var msg = 'Hello world'.codeUnits;
    var isServerClosed = false;
    httpServer.listen((event) {
      event.add(msg);
    }, onDone: () {
      isServerClosed = true;
    });

    var client = TCPClient(config: {});
    var times = 10;
    var times2 = 0;
    for (var i = 0, len = times; i < len; ++i) {
      var temp = await client.connect(host, port1);
      temp.listen((data) async {
        expect(utf8.decode(data).contains('Hello world'), true);
        times2 += 1;
      }, onDone: () async {
        await temp.close();
      });
      await temp.add(buildHTTPProxyRequest(domain));
    }
    await delay(1);

    var userName =
        sha224.convert('123'.codeUnits).toString().codeUnits.toString();
    var user = userList[userName]!;
    expect(times2, times);
    expect(user.traffic.activeLinkCount, times);
    expect(isServerClosed, false);
    await httpServer.close();
    await delay(1);
    expect(isServerClosed, true);
  });
}
