import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/transport/client/ws.dart';

import 'package:proxy/transport/server/base.dart';
import 'package:proxy/transport/server/tcp.dart';

import 'package:proxy/inbounds/base.dart';
import 'package:proxy/inbounds/http.dart';
import 'package:proxy/inbounds/socks5.dart';
import 'package:proxy/inbounds/trojan.dart';

import 'package:proxy/outbounds/base.dart';
import 'package:proxy/outbounds/freedom.dart';
import 'package:proxy/outbounds/block.dart';
import 'package:proxy/outbounds/http.dart';
import 'package:proxy/outbounds/trojan.dart';

import 'package:proxy/route/route.dart';

import 'package:proxy/utils/utils.dart';
import 'package:proxy/obj_list.dart';

import 'transport/mux.dart';

TransportClient1 _buildOutStream(Map<String, dynamic> config) {
  //{{{
  var protocol = getValue(config, 'protocol', 'tcp');

  if (protocol == 'ws') {
    return WSClient2(config: config);
  }
  return TCPClient2(config: config);
} //}}}

MuxClient buildOutStream(String tag, Map<String, dynamic> config) {
  //{{{
  config['tag'] = tag;
  var res = MuxClient(transportClient1: _buildOutStream(config));
  outStreamList[tag] = res;
  return res;
} //}}}

TransportServer1 _buildInStream(Map<String, dynamic> config) {
  //{{{
  var protocol = getValue(config, 'protocol', 'tcp');

  if (protocol == 'ws') {}
  return TCPServer2(config: config);
} //}}}

MuxServer buildInStream(String tag, Map<String, dynamic> config) {
  //{{{
  config['tag'] = tag;
  var res = MuxServer(transportServer1: _buildInStream(config));
  inStreamList[tag] = res;
  return res;
} //}}}

Future<InboundStruct> _buildInbounds(Map<String, dynamic> config) async {
  //{{{
  var protocol = getValue(config, 'protocol', 'socks5');

  InboundStruct res;
  if (protocol == 'http') {
    res = HTTPIn(config: config);
  } else if (protocol == 'trojan') {
    res = TrojanIn(config: config);
  } else {
    res = Socks5In(config: config);
  }
  await res.bind();
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
  var protocol = getValue(config, 'protocol', 'trojan');

  if (protocol == 'http') {
    return HTTPOut(config: config);
  } else if (protocol == 'block') {
    return BlockOut(config: config);
  } else if (protocol == 'trojan') {
    return TrojanOut(config: config);
  }
  return FreedomOut(config: config);
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

Future<void> entry(Map<String, dynamic> allConfig) async {
  var item = {
    'inStream': buildInStream,
    'outStream': buildOutStream,
    'inbounds': buildInbounds,
    'outbounds': buildOutbounds,
    'routes': buildRoute,
  };

  item.forEach(
    (key, value) {
      if (allConfig.containsKey(key)) {
        var temp = (allConfig[key] as Map<String, dynamic>);
        temp.forEach(
          (tag, content) {
            value(tag, content);
          },
        );
      }
    },
  );
}
