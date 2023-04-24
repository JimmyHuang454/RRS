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

    var serverDoneTimes = 0;
    var serverErrorTimes = 0;

    s.listen(
      (inClient) {
        inClient.listen((event) {
          inClient.add(event);
          inClient.close();
        }, onDone: () {
          serverDoneTimes += 1;
        }, onError: (e, r) {
          serverErrorTimes += 1;
        });
      },
    );

    var msg = 'f'.codeUnits;
    var times = 10;
    var time = 0;
    var doneTimes = 0;
    var errorTimes = 0;
    for (var i = 0; i < times; ++i) {
      var c = await client.connect(host, port);
      c.listen((event) {
        expect(event, msg);
        time += 1;
      }, onDone: () {
        doneTimes += 1;
      }, onError: (e, r) {
        errorTimes += 1;
      });
      c.add(msg);
      c.close();
    }

    await delay(3);
    expect(time, times);
    expect(doneTimes, times);
    expect(errorTimes, 0);

    expect(serverDoneTimes, times);
    expect(serverErrorTimes, 0);
  }); //}}}
}
