import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http2/http2.dart';
import 'package:proxy/handler.dart';
import 'package:proxy/utils/utils.dart';
import 'package:test/test.dart';

Future<ClientTransportConnection> connectTunnel(
    String proxyHost, int proxyPort, String targetHost,
    [int targetPort = 443]) async {
  var proxy = await Socket.connect(proxyHost, proxyPort,
      timeout: const Duration(seconds: 1));
  const crlf = "\r\n";
  proxy.write("CONNECT $targetHost:$targetPort HTTP/1.1"); // request line
  proxy.write(crlf);
  proxy.write("Host: $targetHost:$targetPort"); // header
  proxy.write(crlf);
  proxy.write(crlf);
  var completer = Completer<bool>.sync();
  var sub = proxy.listen((event) {
    var response = ascii.decode(event);
    var lines = response.split(crlf);
    // status line
    var statusLine = lines.first;
    if (statusLine.startsWith("HTTP/1.1 200")) {
      completer.complete(true);
    } else {
      completer.completeError(statusLine);
    }
  }, onError: completer.completeError);
  await completer.future; // established
  sub.pause();

  var socket = await SecureSocket.secure(proxy,
      host: targetHost, supportedProtocols: const ["h2"]);
  return ClientTransportConnection.viaSocket(socket);
}

void main() async {
  var host = '127.0.0.1';

  test('jls forward.', () async {
    var serverPort = await getUnusedPort(InternetAddress(host));
    var fallback = 'baidu.com';
    entry({
      "config": {
        "log": {"level": "debug"}
      },
      'inbounds': {
        'jlsInt': {
          "protocol": "trojan",
          "route": 'freedom',
          "setting": {"address": host, "port": serverPort, "password": '12'},
          "inStream": {
            'jls': {
              'enable': true,
              'password': '123',
              'random': '456',
              'fallback': fallback
            } as dynamic
          }
        }
      }
    });
    await delay(1);
    var client = await Socket.connect(host, serverPort);
    var socket = await SecureSocket.secure(client, host: fallback);
    var isClosed = false;
    socket.add(buildHTTPProxyRequest(fallback));
    socket.listen((event) {
      var res = utf8.decode(event);
      devPrint(res);
      expect(res.contains(fallback), true);
    }, onDone: () {
      isClosed = true;
    });
    await delay(1);
    socket.close();
    await delay(1);
    expect(isClosed, true);
  });

  test('jls config2.', () async {
    // httpin -> jlsHttpout -> jlsHttpIn -> freedom
    var config = await readConfigWithJson5('./test/jls/jls.json');
    var host = '127.0.0.1';
    var httpInPort = await getUnusedPort(InternetAddress(host));
    var port2 = await getUnusedPort(InternetAddress(host));
    config['inbounds']['HTTPIn']['setting']['port'] = httpInPort;
    config['inbounds']['HTTPIn2']['setting']['port'] = port2;
    config['outbounds']['jlsHttpout']['setting']['port'] = port2;
    entry(config);

    var website = 'uif03.top';
    var transport = await connectTunnel('127.0.0.1', httpInPort, website);

    var stream = transport.makeRequest([
      Header.ascii(':method', 'GET'),
      Header.ascii(':path', '/'),
      Header.ascii(':scheme', 'https'),
      Header.ascii(':authority', website),
    ], endStream: true);
    await for (var message in stream.incomingMessages) {
      if (message is HeadersStreamMessage) {
        for (var header in message.headers) {
          var name = utf8.decode(header.name);
          var value = utf8.decode(header.value);
          // print('Header: $name: $value');
        }
      } else if (message is DataStreamMessage) {
        var value = utf8.decode(message.bytes);
        expect(value.contains('fuck'), true);
        // print('Body: $value');
      }
    }
    await transport.finish();
  });
}
