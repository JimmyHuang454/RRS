import 'dart:io';

import 'package:proxy/handler.dart';
import 'package:proxy/utils/utils.dart';
import 'package:test/test.dart';

void main() async {
  var host = '127.0.0.1';
  var serverPort = await getUnusedPort(InternetAddress(host));

  test('jls stream.', () async {
    var client = buildOutStream('jls', {
      'jls': {'enabled': true}
    });
    var server = buildInStream('jls', {
      'jls': {'enabled': true}
    });
    var serverListen = await server.bind(host, serverPort);
    serverListen.listen((inClient) {
      inClient.listen((data) async {
        inClient.add(data);
      });
    });

    var c = await client.connect(host, serverPort);
    var receiveTime = 0;
    c.add(zeroList());
    c.listen((data) async {
      receiveTime += 1;
    });
    await delay(1);

    expect(receiveTime, 1);
  });
}
