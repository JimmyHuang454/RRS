import 'dart:convert';

import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/transport/client/ws.dart';
import 'package:proxy/transport/client/base.dart';

import 'package:proxy/transport/server/base.dart';
import 'package:proxy/transport/server/tcp.dart';
import 'package:proxy/utils/utils.dart';

var outStream = '''{
  "protocol": "tcp",
  "setting": {},
  "mux": {"enabled": false, "concurrency": 10},
  "tls": {"enabled": true, "alpn": ["h2", "http/1.1"], "useSystemRoot": true, "certificate":""},

  "fakeRoute": {"enabled": false},
  "ip": {"strategy": "default"}
}''';

var inStream = '''{
  "protocol": "tcp",
  "setting": {},
  "mux": {"enabled": false, "concurrency": 10},
  "tls": {"enabled": true, "requireClientCertificate": true, "certificate":"", "key": ""},
}''';

TransportClient Function() buildClientStream(Map<String, dynamic> stream) {
  //{{{
  var protocol = getValue(stream, 'protocol', 'tcp');
  var useTLS = getValue(stream, 'tls.enabled', false);
  var allowInsecure = getValue(stream, 'tls.allowInsecure', false);
  var supportedProtocols = getValue(stream, 'tls.alpn', []);
  var useSystemRoot = getValue(stream, 'tls.useSystemRoot', true);

  if (protocol == 'ws') {
    return () => WSClient(
          path: getValue(stream, 'setting.path', '/'),
          header: getValue(stream, 'setting.header', {}),
          userAgent: getValue(stream, 'setting.userAgent', ''),
          useTLS: useTLS,
          useSystemRoot: useSystemRoot,
          allowInsecure: allowInsecure,
        );
  }
  return () => TCPClient(
      useTLS: useTLS,
      useSystemRoot: useSystemRoot,
      allowInsecure: allowInsecure,
      supportedProtocols: supportedProtocols);
} //}}}

TransportServer Function() buildServerStream(Map<String, dynamic> stream) {
  //{{{
  var protocol = getValue(stream, 'protocol', 'tcp');
  var useTLS = getValue(stream, 'tls.enabled', false);
  var supportedProtocols = getValue(stream, 'tls.alpn', []);

  if (protocol == 'ws') {
  }
  return () => TCPServer(
      useTLS: useTLS,
      supportedProtocols: supportedProtocols);
} //}}}

void main(List<String> arguments) {
  buildClientStream(jsonDecode(inStream));
  buildServerStream(jsonDecode(inStream));
}
