import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';

import 'package:proxy/handler.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/utils/utils.dart';

void main() async {
  var config = await readConfigWithJson5('./test/socks5/socks5.json');
  var host = '127.0.0.1';
  var port1 = await getUnusedPort(InternetAddress(host));
  var port2 = await getUnusedPort(InternetAddress(host));
  var serverPort = await getUnusedPort(InternetAddress(host));
  var domain = '$host:$serverPort';
  config['inbounds']['HTTPIn']['setting']['port'] = port1;
  config['inbounds']['socks5Inbound']['setting']['port'] = port2;
  config['outbounds']['socks5Out']['setting']['port'] = port2;
  entry(config);

  Uint8List buildSock5Request(Address host, int p) {
    List<int> res = [];
    res += [5, 1, 0];

    var port = Uint8List(2)..buffer.asByteData().setInt16(0, p, Endian.big);
    res += [5, 1, 0, 1] + host.rawAddress.toList() + port;
    return Uint8List.fromList(res);
  }

  // create server.
  var httpServer = await ServerSocket.bind(host, serverPort);
  var msg = [1];
  httpServer.listen(
    (event) async {
      event.add(msg);
      await event.flush();
      await event.close();
    },
  );

  test('socks5in -> freedom', () async {
    var client = TCPClient(config: {});
    var socks5Res = [];
    var temp = await client.connect(host, port2);
    var times = 0;
    var clientClosed = false;
    temp.listen((data) async {
      socks5Res += data;
      times += 1;
    }, onDone: () async {
      clientClosed = true;
    });
    await temp.add(buildSock5Request(Address(host), serverPort));
    await delay(1);
    expect(clientClosed, true);
    expect(socks5Res, [5, 0, 5, 0, 0, 1, 0, 0, 0, 0, 0, 0] + msg);
    expect(times >= 2, true);
  });

  test('HTTPIn -> socks5Out -> socks5in -> freedom', () async {
    var client = TCPClient(config: {});
    var temp = await client.connect(host, port1);
    var times = 0;
    var socks5Res = [];
    var clientClosed = false;
    temp.listen((data) async {
      socks5Res += data;
      times += 1;
    }, onDone: () async {
      clientClosed = true;
    });
    await temp.add(buildHTTPProxyRequest(domain));
    await delay(1);
    expect(clientClosed, true);
    expect(socks5Res, msg);
    expect(times, 1);
  });

  test('socks5in -> error server.', () async {
    var client = TCPClient(config: {});
    var temp = await client.connect(host, port2);
    var unknowPort = await getUnusedPort(InternetAddress(host));
    var socks5Res = [];
    var clientClosed = false;
    temp.listen((data) async {
      socks5Res += data;
    }, onDone: () async {
      clientClosed = true;
    });
    await temp.add(buildSock5Request(Address(host), unknowPort));
    await delay(3);
    expect(clientClosed, true);
    expect(socks5Res, [5, 0, 5, 1, 0, 1, 0, 0, 0, 0, 0, 0]);
  });
}
