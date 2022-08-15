import 'dart:convert';
import 'dart:io';

import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/transport/client/ws.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/outbounds/http.dart';

var jsonString = '''{
  "protocol": "tcp",
  "setting": {},
  "mux": {"enabled": false, "concurrency": 10},
  "tls": {"enabled": true, "alpn": ["h2", "http/1.1"], "useSystemRoot": true, "certificate":"", "key": ""},
  "fakeRoute": {"enabled": false},
  "ip": {"strategy": "default"}
}''';

dynamic getValue(Map<String, dynamic> map, String key, dynamic defaultValue) {
  var temp = key.split('.');
  dynamic deep = map;
  for (var i = 0, len = temp.length; i < len; ++i) {
    try {
      if (deep.containsKey(temp[i])) {
        deep = deep[temp[i]];
        continue;
      }
    } catch (_) {}
    return defaultValue;
  }
  return deep;
}

TransportClient Function() buildStream(Map<String, dynamic> stream) {
  var securityContext = SecurityContext(
      withTrustedRoots: getValue(stream, 'tls.useSystemRoot', true));

  if (!stream.containsKey('protocol')) {}

  var protocol = getValue(stream, 'protocol', 'tcp');
  var useTLS = getValue(stream, 'tls.enabled', true);
  var allowInsecure = getValue(stream, 'tls.allowInsecure', false);
  var supportedProtocols = getValue(stream, 'tls.alpn', []);

  if (protocol == 'ws') {
    return () => WSClient(
          path: getValue(stream, 'setting.path', '/'),
          header: getValue(stream, 'setting.header', {}),
          userAgent: getValue(stream, 'setting.userAgent', ''),

          useTLS: useTLS,
          securityContext: securityContext,
          allowInsecure: allowInsecure,
        );
  }
  return () => TCPClient(
      useTLS: useTLS,
      securityContext: securityContext,
      allowInsecure: allowInsecure,
      supportedProtocols: supportedProtocols);
}

void main(List<String> arguments) {
  buildStream(jsonDecode(jsonString));
}
