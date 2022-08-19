import 'dart:async';
import 'dart:io';

import 'package:proxy/inbounds/base.dart';
import 'package:proxy/outbounds/base.dart';

class BlockOut extends OutboundStruct {
  BlockOut({required super.config})
      : super(protocolName: 'block', protocolVersion: '1');

  @override
  Future<Socket> connect2(Link link) async {
    throw 'block this.';
  }
}
