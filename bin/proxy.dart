import 'dart:convert';
import 'dart:io';

import 'package:proxy/proxy.dart' as proxy;
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/outbounds/http.dart';

var jsonString = '''{
  "protocol": "tcp",
  "setting": {},
  "mux": {"enabled": false, "concurrency": 10},
  "tls": {"enabled": true, "alpn": ["h2", "http/1.1"], "useSystemRoot": true, "certificate":"", "key": ""},
  "fakeRoute": {"enabled": false},
  "ip": {"strategy": "default"},
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

  if (getValue(stream, 'protocol', 'tcp')) {
    
  }

  return () {
    return TCPClient(
        securityContext: securityContext,
        allowInsecure: getValue(stream, 'tls.allowInsecure', false),
        supportedProtocols: getValue(stream, 'tls.alpn', []));
  };
}

void main(List<String> arguments) {
  buildStream(jsonDecode(jsonString));
}
