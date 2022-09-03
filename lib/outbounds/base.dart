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

  String realOutAddress = '';
  int realOutPort = 0;

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
  }

  MuxClient newClient() {
    if (!outStreamList.containsKey(outStreamTag)) {
      throw "wrong outStreamTag.";
    }
    return outStreamList[outStreamTag]!;
  }

  Future<RRSSocket> newConnect(Link l) async {
    realOutAddress = l.targetAddress.address;
    realOutPort = l.targetport;
    var temp = newClient();
    return Connect2(
        rrsSocket: await temp.connect(realOutAddress, realOutPort),
        link: l,
        outboundStruct: this);
  }
}
