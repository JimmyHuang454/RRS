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

  test('jls logic.', () async {
    entry({
      'outStream': {
        'jls': {
          'jls':
              {'enabled': true, 'password': '123', 'random': '456'} as dynamic
        }
      },
      'inStream': {
        'jls': {
          'jls':
              {'enabled': true, 'password': '123', 'random': '456'} as dynamic
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
    c.listen((data) async {
      expect(data, msg);
    }, onDone: () async {
      clientClosed = true;
    });
    c.add(buildHTTPProxyRequest(domain));
    await delay(1);
    expect(clientClosed, true);
  });
}
