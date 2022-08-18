import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/transport/client/ws.dart';

import 'package:proxy/transport/server/base.dart';
import 'package:proxy/transport/server/tcp.dart';

import 'package:proxy/inbounds/base.dart';
import 'package:proxy/inbounds/http.dart';

import 'package:proxy/outbounds/base.dart';
import 'package:proxy/outbounds/freedom.dart';

import 'package:proxy/route/route.dart';

import 'package:proxy/utils/utils.dart';
import 'package:proxy/obj_list.dart';

TransportClient Function() _buildOutStream(Map<String, dynamic> config) {
  //{{{
  var protocol = getValue(config, 'protocol', 'tcp');

  if (protocol == 'ws') {
    return () => WSClient(config: config);
  }
  return () => TCPClient(config: config);
} //}}}

TransportClient Function() buildOutStream(
    String tag, Map<String, dynamic> config) {
  //{{{
  config['tag'] = tag;
  var res = _buildOutStream(config);
  outStreamList[tag] = res;
  return res;
} //}}}

TransportServer Function() _buildInStream(Map<String, dynamic> config) {
  //{{{
  var protocol = getValue(config, 'protocol', 'tcp');

  if (protocol == 'ws') {}
  return () => TCPServer(config: config);
} //}}}

TransportServer Function() buildInStream(
    String tag, Map<String, dynamic> config) {
  //{{{
  config['tag'] = tag;
  var res = _buildInStream(config);
  inStreamList[tag] = res;
  return res;
} //}}}

Future<InboundStruct> _buildInbounds(Map<String, dynamic> config) async {
  //{{{
  var protocol = getValue(config, 'protocol', 'http');

  if (protocol == 'ws') {}
  var res = HTTPIn(config: config);
  await res.bind2();
  return res;
} //}}}

Future<InboundStruct> buildInbounds(
    String tag, Map<String, dynamic> config) async {
  //{{{
  config['tag'] = tag;
  var res = await _buildInbounds(config);
  inboundsList[tag] = res;
  return res;
} //}}}

OutboundStruct _buildOutbounds(Map<String, dynamic> config) {
  //{{{
  var protocol = getValue(config, 'protocol', 'http');

  if (protocol == 'ws') {}
  var res = FreedomOut(config: config);
  return res;
} //}}}

OutboundStruct buildOutbounds(String tag, Map<String, dynamic> config) {
  //{{{
  config['tag'] = tag;
  var res = _buildOutbounds(config);
  outboundsList[tag] = res;
  return res;
} //}}}

Route _buildRoute(Map<String, dynamic> config) {
  //{{{
  var res = Route(config: config);
  return res;
} //}}}

Route buildRoute(String tag, Map<String, dynamic> config) {
  //{{{
  config['tag'] = tag;
  var res = _buildRoute(config);
  routeList[tag] = res;
  return res;
} //}}}

void entry(Map<String, dynamic> allConfig) {
  var item = {
    'inStream': buildInStream,
    'outStream': buildOutStream,
    'route': buildRoute,
    'outbounds': buildOutbounds
  };

  item.forEach(
    (key, value) {
      if (allConfig.containsKey(key)) {
        var temp = (allConfig[key] as Map<String, dynamic>);
        temp.forEach(
          (key, value) {
            value(key, value);
          },
        );
      }
    },
  );

  if (allConfig.containsKey('inbounds')) {
    var inbounds = (allConfig['inbounds'] as Map<String, dynamic>);
    inbounds.forEach(
      (key, value) async {
        await buildInbounds(key, value);
      },
    );
  }
}
