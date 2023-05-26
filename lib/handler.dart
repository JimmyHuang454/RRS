import 'package:proxy/balance/balancer.dart';
import 'package:proxy/config.dart';
import 'package:proxy/outbounds/socks5.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/client/grpc.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/transport/client/ws.dart';

import 'package:proxy/transport/server/base.dart';
import 'package:proxy/transport/server/grpc.dart';
import 'package:proxy/transport/server/tcp.dart';
import 'package:proxy/transport/server/ws.dart';

import 'package:proxy/inbounds/base.dart';
import 'package:proxy/inbounds/http.dart';
import 'package:proxy/inbounds/socks5.dart';
import 'package:proxy/inbounds/trojan.dart';

import 'package:proxy/outbounds/base.dart';
import 'package:proxy/outbounds/freedom.dart';
import 'package:proxy/outbounds/block.dart';
import 'package:proxy/outbounds/http.dart';
import 'package:proxy/outbounds/trojan.dart';

import 'package:proxy/route/mmdb.dart';
import 'package:proxy/route/route.dart';

import 'package:proxy/utils/default_setting.dart';
import 'package:proxy/utils/utils.dart';

import 'package:proxy/obj_list.dart';

import 'package:proxy/dns/dns.dart';

TransportClient _buildOutStream(Map<String, dynamic> config) {
  //{{{
  var protocol = getValue(config, 'protocol', 'tcp');

  if (protocol == 'ws') {
    return WSClient(config: config);
  } else if (protocol == 'grpc') {
    return GRPCClient(config: config);
  }
  return TCPClient(config: config);
} //}}}

TransportClient buildOutStream(String tag, Map<String, dynamic> config) {
  //{{{
  config['tag'] = tag;
  var res = _buildOutStream(config);
  outStreamList[tag] = res;
  return res;
} //}}}

TransportServer _buildInStream(Map<String, dynamic> config) {
  //{{{
  var protocol = getValue(config, 'protocol', 'tcp');

  if (protocol == 'ws') {
    return WSServer(config: config);
  } else if (protocol == 'grpc') {
    return GRPCServer(config: config);
  }
  return TCPServer(config: config);
} //}}}

TransportServer buildInStream(String tag, Map<String, dynamic> config) {
  //{{{
  config['tag'] = tag;
  var res = _buildInStream(config);
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
  } else if (protocol == 'freedom') {
    return FreedomOut(config: config);
  } else if (protocol == 'socks5') {
    return Socks5Out(config: config);
  } else {
    throw "there are no outbound protocol named '$protocol'";
  }
} //}}}

OutboundStruct buildOutbounds(String tag, Map<String, dynamic> config) {
  //{{{
  config['tag'] = tag;
  var res = _buildOutbounds(config);
  outboundsList[tag] = res;
  return res;
} //}}}

Route buildRoute(String tag, Map<String, dynamic> config) {
  //{{{
  config['tag'] = tag;
  var res = Route(config: config);
  routeList[tag] = res;
  return res;
} //}}}

void buildData(String tag, Map<String, dynamic> config) {
  //{{{
  if (tag == 'ipdb') {
    config.forEach(
      (key, value) {
        ipdbList[key] = MMDB(key, value['path']);
      },
    );
  }
} //}}}

void buildDNS(String tag, Map<String, dynamic> config) {
  //{{{
  config['tag'] = tag;
  var type = getValue(config, 'type', 'doh');

  DNS dns;
  if (type == 'udp') {
    // TODO
    dns = DoH(config: config);
  } else {
    dns = DoH(config: config);
  }

  dnsList[tag] = dns;
} //}}}

void buildBalance(String tag, Map<String, dynamic> config) {
  //{{{
  config['tag'] = tag;
  balancerList[tag] = Balancer(config: config);
} //}}}

void buildConifg(String tag, Map<String, dynamic> config) {
  //{{{
  if (tag == 'log') {
    applyLogConfig(config);
  }
} //}}}

void _entry(Map<String, dynamic> config) {
  var list = [
    ['config', buildConifg],
    ['data', buildData],
    ['dns', buildDNS],
    ['outStream', buildOutStream],
    ['inStream', buildInStream],
    ['outbounds', buildOutbounds],
    ['balance', buildBalance],
    ['routes', buildRoute],
    ['inbounds', buildInbounds],
  ];

  for (var i = 0, len = list.length; i < len; ++i) {
    var key = list[i][0];
    var fuc = list[i][1] as Function;
    if (config.containsKey(key)) {
      var temp = config[key];
      temp.forEach(
        (tag, content) {
          fuc(tag, content);
        },
      );
    }
  }
}

void entry(Map<String, dynamic> allConfig) {
  _entry(defaultSetting);
  _entry(allConfig);
}
