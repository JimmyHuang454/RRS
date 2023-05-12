import 'dart:async';

import 'package:proxy/inbounds/base.dart';
import 'package:proxy/outbounds/base.dart';
import 'package:proxy/transport/client/base.dart';

class BlockOut extends OutboundStruct {
  BlockOut({required super.config})
      : super(protocolName: 'block', protocolVersion: '1');

  @override
  Future<RRSSocket> newConnect(Link l) async {
    outAddress = l.targetAddress;
    outPort = l.targetport;
    await l.closeClient();
    throw Exception('block this.');
  }
}
