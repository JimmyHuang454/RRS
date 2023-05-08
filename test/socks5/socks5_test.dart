import 'dart:io';
import 'dart:typed_data';
import 'package:quiver/collection.dart';
import 'package:test/test.dart';

import 'package:proxy/handler.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/utils/utils.dart';

void main() {
  test('socks5 -> freedom', () async {
    var config = await readConfigWithJson5('./test/socks5/socks5.json');
    var host = '127.0.0.1';
    var port1 = await getUnusedPort(InternetAddress(host));
    var serverPort = await getUnusedPort(InternetAddress(host));
    config['inbounds']['socks5Inbound']['setting']['port'] = port1;
    entry(config);

    var httpServer = await ServerSocket.bind(host, serverPort);
    var msg = [1];
    httpServer.listen(
      (event) {
        event.add(msg);
        event.close();
      },
    );

    var client = TCPClient(config: {});
    var temp = await client.connect(host, port1);
    var times = 0;
    var clientClosed = false;
    var socks5Res = [];
    temp.listen((data) {
      socks5Res += data;
      times += 1;
    }, onDone: () {
      clientClosed = true;
    });
    temp.add([5, 1, 0]);

    var port = Uint8List(2)
      ..buffer.asByteData().setInt16(0, serverPort, Endian.big);
    temp.add([5, 1, 0, 1] + Address(host).rawAddress.toList() + port);
    await delay(2);
    expect(clientClosed, true);
    expect(socks5Res, [5, 0, 5, 0, 0, 1, 0, 0, 0, 0, 0, 0] + msg);
    expect(times >= 2, true);
  });

  test('HTTPIn -> socks5Out -> socks5in -> freedom', () async {
    var config = await readConfigWithJson5('./test/socks5/socks5.json');
    var host = '127.0.0.1';
    var port1 = await getUnusedPort(InternetAddress(host));
    var port2 = await getUnusedPort(InternetAddress(host));
    var serverPort = await getUnusedPort(InternetAddress(host));
    var domain = '$host:$serverPort';
    var socks5Res = [];
    config['inbounds']['HTTPIn']['setting']['port'] = port1;
    config['inbounds']['socks5Inbound']['setting']['port'] = port2;
    config['outbounds']['socks5Out']['setting']['port'] = port2;
    entry(config);

    var httpServer = await ServerSocket.bind(host, serverPort);
    var msg = [1];
    httpServer.listen(
      (event) {
        event.add(msg);
        event.close();
      },
    );

    var client = TCPClient(config: {});
    var temp = await client.connect(host, port1);
    var times = 0;
    var clientClosed = false;
    temp.listen((data) {
      socks5Res += data;
      times += 1;
    }, onDone: () {
      clientClosed = true;
    });
    temp.add(buildHTTPProxyRequest(domain));
    await delay(2);
    expect(clientClosed, true);
    expect(socks5Res, msg);
    expect(times, 1);
  });
}
