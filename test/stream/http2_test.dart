import 'dart:convert';
import 'dart:io';

import 'package:proxy/handler.dart';
import 'package:proxy/utils/utils.dart';
import 'package:proxy/transport/client/h2.dart';

import 'package:test/test.dart';
import 'package:http2/http2.dart';

Map<String, Map<String, dynamic>> liveConnection = {};

void main() {
  test('http2', () async {
    var host = '127.0.0.1';
    var port = 7767;
    var s = await ServerSocket.bind(host, port);
    s.listen(
      (event) {
        var temp = ServerTransportConnection.viaSocket(event);
        temp.incomingStreams.listen(
          (client) async {
            client.sendData(utf8.encode('fuck'));
            client.incomingMessages.listen(
              (message) {
                if (message is DataStreamMessage) {
                  devPrint(utf8.decode(message.bytes));
                }
              },
            );
            client.outgoingMessages.close();
          },
        );
      },
    );

    var client = buildOutStream('c', {
      'protocol': 'h2',
      'setting': {'path': 'abc'}
    });

    var c = await client.connect(host, port);
    c.add('fuck'.codeUnits);
    await delay(3);
  });
}
