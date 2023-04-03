import 'dart:async';

import 'package:proxy/transport/mux.dart';
import 'package:proxy/user.dart';
import 'package:proxy/utils/utils.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/obj_list.dart';

abstract class OutboundStruct {
  String protocolName;
  String protocolVersion;
  Map<String, dynamic> config;

  String tag = '';
  String outStreamTag = '';
  String outAddress = '';
  int outPort = 0;
  Traffic traffic = Traffic();

  int linkNr = 0;

  String realOutAddress = '';
  int realOutPort = 0;

  late MuxClient _muxClient;

  OutboundStruct(
      {required this.protocolName,
      required this.protocolVersion,
      required this.config}) {
    tag = getValue(config, 'tag', '');
    outStreamTag = getValue(config, 'outStream', '');
    outAddress = getValue(config, 'setting.address', '');
    outPort = getValue(config, 'setting.port', 0);

    realOutAddress = outAddress;
    realOutPort = outPort;

    if (!outStreamList.containsKey(outStreamTag) && protocolName != 'block') {
      throw 'wrong outStream named "$outStreamTag"';
    }

    if (protocolName != 'block') {
      _muxClient = outStreamList[outStreamTag]!;
    }
  }

  MuxClient getClient() {
    return _muxClient;
  }

  Future<RRSSocket> newConnect(Link l) async {
    realOutAddress = l.targetAddress!.address;
    realOutPort = l.targetport!;
    return Connect(
        rrsSocket: await getClient().connect(realOutAddress, realOutPort),
        link: l,
        outboundStruct: this);
  }
}
