import 'dart:convert';
import 'dart:io';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/transport/client/ws.dart';

import 'package:proxy/transport/server/base.dart';
import 'package:proxy/transport/server/tcp.dart';

import 'package:proxy/inbounds/base.dart';
import 'package:proxy/inbounds/http.dart';

import 'package:proxy/utils/utils.dart';
import 'package:proxy/obj_list.dart';

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
  config['tag'] = tag;

  if (protocol == 'ws') {
    return () => WSClient(config: config);
  }
  return () => TCPClient(config: config);
} //}}}

TransportServer Function() buildInStream(
    String tag, Map<String, dynamic> config) {
  //{{{
  var protocol = getValue(config, 'protocol', 'tcp');
  config['tag'] = tag;

  if (protocol == 'ws') {}
  return () => TCPServer(config: config);
} //}}}

Future<InboundStruct> buildInbounds(
    String tag, Map<String, dynamic> config) async {
  //{{{
  var protocol = getValue(config, 'protocol', 'http');
  config['tag'] = tag;

  if (protocol == 'ws') {}
  var res = HTTPIn(config: config);
  await res.bind2();
  return res;
} //}}}

void main(List<String> arguments) async {
  var configFile = File(
      'C:/Users/qwer/Desktop/vimrc/myproject/ECY/flutter/proxy2/proxy/config/basic.json');
  var config = await configFile.readAsString();
  var configJson = (jsonDecode(config) as Map<String, dynamic>);

  if (configJson.containsKey('inStream')) {
    var inStream = (configJson['inStream'] as Map<String, dynamic>);
    inStream.forEach(
      (key, value) {
        inStreamList[key] = buildInStream(key, value);
      },
    );
  }

  if (configJson.containsKey('outStream')) {
    var outStream = (configJson['outStream'] as Map<String, dynamic>);
    outStream.forEach(
      (key, value) {
        outStreamList[key] = buildOutStream(key, value);
      },
    );
  }

  if (configJson.containsKey('inbounds')) {
    var inbounds = (configJson['inbounds'] as Map<String, dynamic>);
    inbounds.forEach(
      (key, value) async {
        inboundsList[key] = await buildInbounds(key, value);
      },
    );
  }

  print(inStreamList);
  print(outStreamList);
}
