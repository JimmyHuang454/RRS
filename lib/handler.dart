import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/transport/client/ws.dart';

import 'package:proxy/transport/server/base.dart';
import 'package:proxy/transport/server/tcp.dart';

import 'package:proxy/inbounds/base.dart';
import 'package:proxy/inbounds/http.dart';

import 'package:proxy/utils/utils.dart';
import 'package:proxy/obj_list.dart';

TransportClient Function() _buildOutStream(
    String tag, Map<String, dynamic> config) {
  //{{{
  var protocol = getValue(config, 'protocol', 'tcp');
  config['tag'] = tag;

  if (protocol == 'ws') {
    return () => WSClient(config: config);
  }
  return () => TCPClient(config: config);
} //}}}

TransportClient Function() buildOutStream(
    String tag, Map<String, dynamic> config) {
  //{{{
  var res = _buildOutStream(tag, config);
  outStreamList[tag] = res;
  return res;
} //}}}

TransportServer Function() _buildInStream(
    String tag, Map<String, dynamic> config) {
  //{{{
  var protocol = getValue(config, 'protocol', 'tcp');
  config['tag'] = tag;

  if (protocol == 'ws') {}
  return () => TCPServer(config: config);
} //}}}

TransportServer Function() buildInStream(
    String tag, Map<String, dynamic> config) {
  //{{{
  var res = _buildInStream(tag, config);
  inStreamList[tag] = res;
  return res;
} //}}}

Future<InboundStruct> _buildInbounds(
    String tag, Map<String, dynamic> config) async {
  //{{{
  var protocol = getValue(config, 'protocol', 'http');
  config['tag'] = tag;

  if (protocol == 'ws') {}
  var res = HTTPIn(config: config);
  await res.bind2();
  return res;
} //}}}

Future<InboundStruct> buildInbounds(
    String tag, Map<String, dynamic> config) async {
  //{{{
  var res = await _buildInbounds(tag, config);
  inboundsList[tag] = res;
  return res;
} //}}}

Future<InboundStruct> buildRoute(
    String tag, Map<String, dynamic> config) async {
  //{{{
  var res = await _buildInbounds(tag, config);
  inboundsList[tag] = res;
  return res;
} //}}}
