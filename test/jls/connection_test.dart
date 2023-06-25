import 'dart:io';

import 'package:cryptography/helpers.dart';
import 'package:proxy/handler.dart';
import 'package:proxy/obj_list.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/utils/utils.dart';
import 'package:test/test.dart';

void main() async {
  var host = '127.0.0.1';
  var serverPort = await getUnusedPort(InternetAddress(host));
  var random = randomBytes(30000);

  test('jls logic.', () async {
    entry({
      'outStream': {
        'jls': {
          'jls': {'enable': true, 'password': '123', 'random': '456'} as dynamic
        }
      },
      'inStream': {
        'jls': {
          'jls': {'enable': true, 'password': '123', 'random': '456'} as dynamic
        }
      }
    });

    var client = outStreamList['jls']!;
    var server = inStreamList['jls']!;
    var serverListen = await server.bind(host, serverPort);
    serverListen.listen((inClient) {
      inClient.listen((data) async {
        inClient.add(data);
      }, onError: (e, s) async {
        devPrint(e);
      }, onDone: () async {
        devPrint(2);
      });
    });

    List<int> receivedata = [];
    var times = 2;
    var isClose = false;
    for (var i = 0; i < times; i++) {
      var c = await client.connect(host, serverPort);
      c.listen((data) async {
        receivedata += data;
      }, onDone: () async {
        isClose = true;
      }, onError: (e, s) async {
        isClose = true;
      });
      c.add(random);
      expect(isClose, false);
    }
    await delay(2);
    expect(receivedata.length, random.length * times);
  });

  test('jls config.', () async {
    // httpin -> jlsHttpout -> jlsHttpIn -> freedom
    var config = await readConfigWithJson5('./test/jls/jls.json');
    var host = '127.0.0.1';
    var httpInPort = await getUnusedPort(InternetAddress(host));
    var port2 = await getUnusedPort(InternetAddress(host));
    var serverPort = await getUnusedPort(InternetAddress(host));
    var domain = '$host:$serverPort';
    config['inbounds']['HTTPIn']['setting']['port'] = httpInPort;
    config['inbounds']['HTTPIn2']['setting']['port'] = port2;
    config['outbounds']['jlsHttpout']['setting']['port'] = port2;
    entry(config);

    var httpServer = await ServerSocket.bind(host, serverPort);
    var msg = 'Hello world'.codeUnits;
    httpServer.listen(
      (event) async {
        event.add(msg);
        await event.flush();
        await event.close();
      },
    );
    var client = TCPClient(config: {});
    var c = await client.connect(host, httpInPort);
    var clientClosed = false;
    var isRecive = false;
    c.listen((data) async {
      expect(data, msg);
      isRecive = true;
    }, onDone: () async {
      clientClosed = true;
    });
    c.add(buildHTTPProxyRequest(domain));
    await delay(3);
    expect(isRecive, true);
    expect(clientClosed, true);
  });
}
