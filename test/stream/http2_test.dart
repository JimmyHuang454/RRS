import 'dart:convert';
import 'dart:io';

import 'package:proxy/utils/utils.dart';
import 'package:test/test.dart';
import 'package:http2/http2.dart';

Map<String, Map<String, dynamic>> liveConnection = {};

class H2Request {
  bool endStream = false;
  String hostAndPort = '';
  late Uri uri;
  late ClientTransportConnection con;
  late ClientTransportStream clientTransportStream;
  late Map<String, dynamic> info;

  H2Request(String url, {this.endStream = false}) {
    uri = Uri.parse(url);
    hostAndPort = '${uri.host}:${uri.port}';
  }

  Future<void> _connect() async {
    if (liveConnection.containsKey(hostAndPort)) {
      info = liveConnection[hostAndPort]!;
      con = info['con'];
      info['link'] += 1;
    } else {
      dynamic s;
      if (uri.scheme.startsWith('https')) {
        s = await SecureSocket.connect(
          uri.host,
          uri.port,
          supportedProtocols: ['h2'],
        );
      } else {
        s = await Socket.connect(
          uri.host,
          uri.port,
        );
      }
      con = ClientTransportConnection.viaSocket(s);
      info = {'con': con, 'link': 1};
      liveConnection[hostAndPort] = info;
    }
  }

  Future<ClientTransportStream> get(
      {Map<String, String> header = const {}}) async {
    await _connect();

    List<Header> tempHeader = [
      Header.ascii(':method', 'GET'),
      Header.ascii(':path', uri.path),
      Header.ascii(':scheme', uri.scheme),
      Header.ascii(':authority', uri.host),
    ];
    header.forEach(
      (key, value) {
        tempHeader.add(
          Header.ascii(key, key),
        );
      },
    );
    clientTransportStream = con.makeRequest(tempHeader, endStream: endStream);
    return clientTransportStream;
  }

  Future<void> close() async {
    clientTransportStream.outgoingMessages.close();
    info['link'] -= 1;
    if (info['link'] == 0) {
      liveConnection.remove(hostAndPort);
      await con.finish();
    } else {
      clientTransportStream.outgoingMessages.close();
    }
  }
}

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
