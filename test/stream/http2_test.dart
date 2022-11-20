import 'dart:convert';
import 'dart:io';

import 'package:proxy/handler.dart';
import 'package:proxy/utils/utils.dart';

import 'package:test/test.dart';
import 'package:http2/http2.dart';

Map<String, Map<String, dynamic>> liveConnection = {};

void main() {
  test('http2', () async {
    var host = '127.0.0.1';
    var port = await getUnusedPort(InternetAddress(host));
    var tcpServer = await ServerSocket.bind(host, port);

    tcpServer.listen(
      (inClient) {
        var h2Client = ServerTransportConnection.viaSocket(inClient);
        h2Client.incomingStreams.listen(
          (client) {
            client.incomingMessages.listen(
              (data) {
                devPrint(data);
              },
            );
          },
        );
      },
    );

    var client = buildOutStream('c2', {
      'protocol': 'h2',
      'setting': {'path': 'abc'}
    });

    var c = await client.connect(host, port);
    c.add('fuck'.codeUnits);
    await delay(3);
  });

  test('http2 socket', () async {
    var host = '127.0.0.1';
    var port = await getUnusedPort(InternetAddress(host));
    var server = buildInStream('s', {
      'protocol': 'h2',
      'setting': {'path': 'abc'}
    });
    var s = await server.bind(host, port);

    var msg = 'hello';
    s.listen(
      (inClient) {
        inClient.listen(
          (data) {
            expect(utf8.decode(data) == msg, true);
          },
        );
        inClient.add(utf8.encode(msg));
        inClient.close();
      },
    );

    var client = buildOutStream('c', {
      'protocol': 'h2',
      'setting': {'path': 'abc'}
    });

    var c = await client.connect(host, port);
    c.listen(
      (data) {
        expect(utf8.decode(data) == msg, true);
      },
    );
    c.add(utf8.encode(msg));
    await delay(3);
  });
}
