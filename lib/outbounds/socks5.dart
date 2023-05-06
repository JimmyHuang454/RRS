import 'dart:async';
import 'dart:typed_data';
import 'package:proxy/transport/client/base.dart';

import 'package:proxy/utils/utils.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/outbounds/base.dart';

class Socks5Connect extends Connect {
  bool isAuth = false;
  bool isSendedHeader = false;

  Socks5Connect(
      {required super.link,
      required super.rrsSocket,
      required super.outboundStruct});

  List<int> buildHeader() {
    // +----+-----+-------+------+----------+----------+
    // |VER | CMD |  RSV  | ATYP | DST.ADDR | DST.PORT |
    // +----+-----+-------+------+----------+----------+
    // | 1  |  1  | X'00' |  1   | Variable |    2     |
    // +----+-----+-------+------+----------+----------+

    var cmd = 1; // CONNECT
    if (link.streamType == StreamType.udp) {
      // TODO
      cmd = 3;
    } else {
      // TODO
      cmd = 2; // BIND
    }

    var atyp = 1; // ipv4
    List<int> addr = [];
    if (link.targetAddress!.type == AddressType.domain) {
      addr = [link.targetAddress!.internetAddress.rawAddress.length] +
          link.targetAddress!.internetAddress.rawAddress.toList();
    } else {
      if (link.targetAddress!.type == AddressType.ipv4) {
        atyp = 3;
      } else {
        atyp = 4;
      }
      addr = link.targetAddress!.internetAddress.rawAddress.toList();
    }

    return [
          5,
          cmd,
          0,
          atyp,
        ] +
        addr;
  }

  @override
  void add(List<int> data) {
    if (!isAuth) {
      rrsSocket.add([5, 1, 0]);
      isAuth = true;
    }

    if (!isSendedHeader) {
      isSendedHeader = true;
    }

    if (link.streamType == StreamType.udp) {
      // TODO
    } else {
      super.add(data);
    }
  }
}

class Socks5Out extends OutboundStruct {
  String userAccount = '';
  String userPassword = '';
  bool isBuildConnection = false;

  Socks5Out({required super.config})
      : super(protocolName: 'socks', protocolVersion: '5') {
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
