import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/transport/client/ws.dart';

import 'package:proxy/transport/server/base.dart';
import 'package:proxy/transport/server/tcp.dart';

import 'package:proxy/inbounds/base.dart';
import 'package:proxy/inbounds/http.dart';

import 'package:proxy/utils/utils.dart';

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
