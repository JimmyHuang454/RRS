import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:proxy/obj_list.dart';
import 'package:test/test.dart';

import 'package:proxy/handler.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/utils/utils.dart';

void main() {
  test('trojan', () async {
    var config = await readConfigWithJson5('./test/trojan/trojan.json');
    var host = '127.0.0.1';
    var port1 = await getUnusedPort(InternetAddress(host));
    var port2 = await getUnusedPort(InternetAddress(host));
    var port3 = await getUnusedPort(InternetAddress(host));
    var domain = '$host:$port3';
    config['inbounds']['HTTPIn']['setting']['port'] = port1;
    config['inbounds']['TrojanIn']['setting']['port'] = port2;
    config['outbounds']['TrojanOut']['setting']['port'] = port2;
    entry(config);

    var httpServer = await ServerSocket.bind(host, port3);
    var msg = 'Hello world'.codeUnits;
    httpServer.listen(
      (event) {
        event.add(msg);
        event.close();
      },
    );

    var client = TCPClient(config: {});
    var times = 2;
    var times2 = 0;
    for (var i = 0, len = times; i < len; ++i) {
      var temp = await client.connect(host, port1);
      temp.add(buildHTTPProxyRequest(domain));
      temp.listen((data) {
        expect(utf8.decode(data).contains('Hello world'), true);
      }, onDone: () {
        times2 += 1;
        temp.close();
      });
    }
    await delay(2);
    var userName =
        sha224.convert('123'.codeUnits).toString().codeUnits.toString();
    var user = userList[userName]!;
    expect(times2, times);
    expect(user.linkCount, 0);

    expect(userList.length, 2);
    expect(user.traffic.uplink > 0, true);
    expect(user.traffic.downlink > 0, true);

    user.clearTraffic();
    expect(user.traffic.downlink, 0);
    expect(user.traffic.uplink, 0);
  });
}
