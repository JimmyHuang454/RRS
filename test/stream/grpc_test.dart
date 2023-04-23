import 'dart:io';

import 'package:proxy/handler.dart';
import 'package:proxy/obj_list.dart';
import 'package:test/test.dart';
import 'package:proxy/utils/utils.dart';

void main() {
  test('grpc stream test.', () async {
    //{{{
    entry({
      'outStream': {
        'grpc': {
          'protocol': 'grpc',
          'tls': {'enable': false}
        }
      },
      'inStream': {
        'grpc': {
          'protocol': 'grpc',
          'tls': {'enable': false}
        }
      }
    });
    expect(outStreamList.containsKey('grpc'), true);
    expect(inStreamList.containsKey('grpc'), true);

    var client = outStreamList['grpc']!;
    var server = inStreamList['grpc']!;
    expect(client.protocolName, 'grpc');
    expect(server.protocolName, 'grpc');

    var host = '127.0.0.1';
    var port = await getUnusedPort(InternetAddress(host));
    var s = await server.bind(host, port);

    s.listen(
      (inClient) {
        inClient.listen((event) {
          inClient.add(event);
        }, onDone: (() {}));
      },
    );

    var msg = 'f'.codeUnits;
    var times = 10;
    var time = 0;
    for (var i = 0; i < 10; ++i) {
      var c = await client.connect(host, port);
      c.listen(
        (event) {
          expect(event, msg);
          time += 1;
        },
      );
      c.add(msg);
    }

    await delay(1);
    expect(times, time);

    await delay(1);
  }); //}}}
}
