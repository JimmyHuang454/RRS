import 'dart:convert';
import 'dart:io';

import 'package:proxy/utils/utils.dart';
import 'package:proxy/transport/client/h2.dart';

import 'package:test/test.dart';
import 'package:http2/http2.dart';

Map<String, Map<String, dynamic>> liveConnection = {};

void main() {
  test('http2', () async {
    var s = await ServerSocket.bind('127.0.0.1', 7767);
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

    for (var i = 0, len = 10; i < len; ++i) {
      var req = H2Request('http://127.0.0.1:7767/');
      var stream = await req.get();

      await for (var message in stream.incomingMessages) {
        if (message is DataStreamMessage) {
          devPrint(utf8.decode(message.bytes));
        }
      }
      stream.sendData(utf8.encode('abc'));
      await delay(1);
      await req.close();
    }
  });
}
