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

TransportClient Function() buildOutStream(
    String tag, Map<String, dynamic> config) {
  //{{{
  var protocol = getValue(config, 'protocol', 'tcp');
  if (protocol == 'ws') {
    return () => WSClient(tag: tag, config: config);
  }
  return () => TCPClient(tag: tag, config: config);
} //}}}

TransportServer Function() buildInStream(
    String tag, Map<String, dynamic> config) {
  //{{{
  var protocol = getValue(config, 'protocol', 'tcp');

  if (protocol == 'ws') {}
  return () => TCPServer(tag: tag, config: config);
} //}}}

Map<String, TransportClient Function()> outList = {};
Map<String, TransportServer Function()> inList = {};

void main(List<String> arguments) async {
  var configFile = File(
      'C:/Users/qwer/Desktop/vimrc/myproject/ECY/flutter/proxy2/proxy/config/basic.json');
  var config = await configFile.readAsString();
  var configJson = (jsonDecode(config) as Map<String, dynamic>);

  if (configJson.containsKey('inStream')) {
    var inStream = (configJson['inStream'] as Map<String, dynamic>);
    inStream.forEach(
      (key, value) {
        inList[key] = buildInStream(key, value);
      },
    );
  }

  if (configJson.containsKey('outStream')) {
    var outStream = (configJson['outStream'] as Map<String, dynamic>);
    outStream.forEach(
      (key, value) {
        outList[key] = buildOutStream(key, value);
      },
    );
  }
}
