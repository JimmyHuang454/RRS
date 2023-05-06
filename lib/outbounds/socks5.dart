import 'dart:async';
import 'dart:typed_data';
import 'package:proxy/transport/client/base.dart';

import 'package:proxy/utils/utils.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/outbounds/base.dart';

class Socks5Connect extends Connect {
  void Function(Uint8List event)? onD;
  Function(dynamic e, dynamic s)? onE;
  void Function()? onDo;

  bool isConnected = false;

  Socks5Connect(
      {required super.link,
      required super.rrsSocket,
      required super.outboundStruct});
}

class HTTPOut extends OutboundStruct {
  String userAccount = '';
  String userPassword = '';
  bool isBuildConnection = false;

  HTTPOut({required super.config})
      : super(protocolName: 'http', protocolVersion: '1.1') {
    userAccount = getValue(config, 'setting.account', '');
    userPassword = getValue(config, 'setting.password', '');

    if (outAddress == '' || outPort == 0) {
      throw '"address" and "port" can not be empty in http setting.';
    }
  }

  @override
  Future<RRSSocket> newConnect(Link l) async {
    var res = Socks5Connect(
        rrsSocket: await connect(outAddress, outPort),
        link: l,
        outboundStruct: this);
    return res;
  }
}
