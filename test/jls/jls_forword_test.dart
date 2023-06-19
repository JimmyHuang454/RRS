import 'dart:convert';
import 'dart:io';

import 'package:proxy/handler.dart';
import 'package:proxy/utils/utils.dart';
import 'package:test/test.dart';

void main() async {
  var host = '127.0.0.1';

  test('jls forward.', () async {
    var serverPort = await getUnusedPort(InternetAddress(host));
    var fallback = 'baidu.com';
    entry({
      "config": {
        "log": {"level": "debug"}
      },
      'inbounds': {
        'jlsInt': {
          "protocol": "trojan",
          "route": 'freedom',
          "setting": {"address": host, "port": serverPort, "password": '12'},
          "inStream": {
            'jls': {
              'enabled': true,
              'password': '123',
              'random': '456',
              'fallback': fallback
            } as dynamic
          }
        }
      }
    });
    await delay(1);
    var client = await Socket.connect(host, serverPort);
    var socket = await SecureSocket.secure(client, host: fallback);
    var isClosed = false;
    socket.add(buildHTTPProxyRequest(fallback));
    socket.listen((event) {
      var res = utf8.decode(event);
      devPrint(res);
      expect(res.contains(fallback), true);
    }, onDone: () {
      isClosed = true;
    });
    await delay(1);
    socket.close();
    await delay(1);
    expect(isClosed, true);
  });
}
