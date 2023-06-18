import 'dart:io';

import 'package:cryptography/helpers.dart';
import 'package:proxy/handler.dart';
import 'package:proxy/obj_list.dart';
import 'package:proxy/utils/utils.dart';
import 'package:test/test.dart';

void main() async {
  var host = '127.0.0.1';
  var serverPort = await getUnusedPort(InternetAddress(host));

  test('jls logic.', () async {
    entry({
      'outStream': {
        'jls': {
          'jls': {'enabled': true, 'password': '123', 'random': '456'} as dynamic
        }
      },
      'inStream': {
        'jls': {
          'jls': {'enabled': true, 'password': '123', 'random': '456'} as dynamic
        }
      }
    });

    var client = outStreamList['jls']!;
    var server = inStreamList['jls']!;
    var serverListen = await server.bind(host, serverPort);
    serverListen.listen((inClient) {
      inClient.listen((data) async {
        inClient.add(data);
      });
    });

    var c = await client.connect(host, serverPort);
    List<int> receivedata = [];
    var random = randomBytes(30000);
    c.listen((data) async {
      receivedata += data;
    });
    c.add(random);
    await delay(1);

    expect(receivedata, random);
  });
}
