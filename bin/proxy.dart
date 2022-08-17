import 'dart:convert';
import 'dart:io';

import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/transport/client/ws.dart';
import 'package:proxy/transport/client/base.dart';

import 'package:proxy/transport/server/base.dart';
import 'package:proxy/transport/server/tcp.dart';
import 'package:proxy/utils/utils.dart';

var outStream = '''{
  "protocol": "tcp",
  "setting": {},
  "timeout": 100,
  "mux": {"enabled": false, "concurrency": 10},
  "tls": {"enabled": true, "alpn": ["h2", "http/1.1"], "useSystemRoot": true, "certificate":""},

  "fakeRoute": {"enabled": false},
}''';

var inStream = '''{
  "protocol": "tcp",
  "setting": {},
  "mux": {"enabled": false, "concurrency": 10},
  "tls": {"enabled": true, "requireClientCertificate": true, "certificate":"", "key": ""},
}''';

TransportClient Function() buildOutStream(Map<String, dynamic> stream) {
  //{{{
  var protocol = getValue(stream, 'protocol', 'tcp');
  var useTLS = getValue(stream, 'tls.enabled', false);
  var allowInsecure = getValue(stream, 'tls.allowInsecure', false);
  var supportedProtocols = getValue(stream, 'tls.alpn', []);
  var useSystemRoot = getValue(stream, 'tls.useSystemRoot', true);
  var timeout = getValue(stream, 'timeout', 100);
  var timeout2 = Duration(seconds: timeout);

  if (protocol == 'ws') {
    return () => WSClient(
          path: getValue(stream, 'setting.path', '/'),
          header: getValue(stream, 'setting.header', {}),
          userAgent: getValue(stream, 'setting.userAgent', ''),
          useTLS: useTLS,
          connectionTimeout: timeout2,
          useSystemRoot: useSystemRoot,
          allowInsecure: allowInsecure,
        );
  }
  return () => TCPClient(
      useTLS: useTLS,
      useSystemRoot: useSystemRoot,
      connectionTimeout: timeout2,
      allowInsecure: allowInsecure,
      supportedProtocols: supportedProtocols);
} //}}}

TransportServer Function() buildInStream(Map<String, dynamic> stream) {
  //{{{
  var protocol = getValue(stream, 'protocol', 'tcp');
  var useTLS = getValue(stream, 'tls.enabled', false);
  var supportedProtocols = getValue(stream, 'tls.alpn', []);

  if (protocol == 'ws') {}
  return () =>
      TCPServer(useTLS: useTLS, supportedProtocols: supportedProtocols);
} //}}}

late Map<String, TransportClient Function()> outList;
late Map<String, TransportServer Function()> inList;

void main(List<String> arguments) async {
  var configFile = File(
      'C:/Users/qwer/Desktop/vimrc/myproject/ECY/flutter/proxy2/proxy/config/basic.json');
  var config = await configFile.readAsString();
  var configJson = (jsonDecode(config) as Map<String, dynamic>);

  if (configJson.containsKey('inStream')) {
    var inStream = (configJson['inStream'] as Map<String, dynamic>);
    inStream.forEach(
      (key, value) {
        inList[key] = buildInStream(value);
      },
    );
  }

  if (configJson.containsKey('outStream')) {
    var outStream = (configJson['outStream'] as Map<String, dynamic>);
    outStream.forEach(
      (key, value) {
        outList[key] = buildOutStream(value);
      },
    );
  }
  buildOutStream(jsonDecode(inStream));
}
