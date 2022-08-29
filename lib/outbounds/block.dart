import 'dart:async';

import 'package:proxy/inbounds/base.dart';
import 'package:proxy/outbounds/base.dart';
import 'package:proxy/transport/client/base.dart';

class BlockOut extends OutboundStruct {
  BlockOut({required super.config})
      : super(protocolName: 'block', protocolVersion: '1');

  @override
  Future<TransportClient> newConnect(Link l) async {
    throw 'block this.';
  }
}
