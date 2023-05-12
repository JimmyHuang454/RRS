import 'dart:async';
import 'dart:typed_data';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/utils/const.dart';
import 'package:proxy/outbounds/base.dart';
import 'package:proxy/utils/utils.dart';

class Socks5Connect extends Connect {
  bool isAuth = false;
  bool isReceiveAuth = false;
  bool isReceiveHeaderRespon = false;
  bool isSendedHeader = false;

  List<int> content = [];

  Socks5Connect(
      {required super.link,
      required super.rrsSocket,
      required super.outboundStruct});

  List<int> buildHeader() {
    //{{{
    // +----+-----+-------+------+----------+----------+
    // |VER | CMD |  RSV  | ATYP | DST.ADDR | DST.PORT |
    // +----+-----+-------+------+----------+----------+
    // | 1  |  1  | X'00' |  1   | Variable |    2     |
    // +----+-----+-------+------+----------+----------+

    var cmd = 1; // CONNECT // TODO: implement UDP and BIND.

    var atyp = 1; // ipv4
    List<int> addr = [];
    if (link.targetAddress!.type == AddressType.domain) {
      var temp = link.targetAddress!.rawAddress.toList();
      addr = [temp.length] + temp;
      atyp = 3;
    } else {
      if (link.targetAddress!.type == AddressType.ipv6) {
        atyp = 4;
      }
      addr = link.targetAddress!.rawAddress.toList();
    }

    // add port.
    addr += Uint8List(2)
      ..buffer.asByteData().setInt16(0, link.targetport!, Endian.big);

    return [
          5,
          cmd,
          0,
          atyp,
        ] +
        addr;
  } //}}}

  @override
  Future<void> add(List<int> data) async {
    if (!isAuth) {
      await super.add([5, 1, 0]);
      isAuth = true;
    }

    if (!isSendedHeader) {
      await super.add(buildHeader());
      isSendedHeader = true;
    }

    if (link.streamType == StreamType.udp) {
      // TODO
    } else {
      await super.add(data);
    }
  }

  @override
  void listen(Future<void> Function(Uint8List event)? onData,
      {Future<void> Function(dynamic e, dynamic s)? onError,
      Future<void> Function()? onDone}) {
    super.listen((event) async {
      content += event;

      if (!isReceiveAuth) {
        if (content.length < 2) {
          return;
        }
        if (content[1] != 0) {
          // auth wrong.
          await link.closeClient();
          return;
        }
        content = content.sublist(2);
        isReceiveAuth = true;
      }

      if (!isReceiveHeaderRespon) {
        if (content.length >= 3 && content[1] != 0) {
          // CONNECT wrong.
          await link.closeClient();
          return;
        }

        if (content.length < 10) {
          // only accept ipv4 address.
          return;
        }
        content = content.sublist(10);
        isReceiveHeaderRespon = true;
      }

      if (content.isNotEmpty) {
        await onData!(Uint8List.fromList(content));
        content = [];
      }
    }, onDone: onDone, onError: onError);
  }
}

class Socks5Out extends OutboundStruct {
  String userAccount = '';
  String userPassword = '';
  bool isBuildConnection = false;

  Socks5Out({required super.config})
      : super(protocolName: 'socks', protocolVersion: '5') {
    var settingAddress = getValue(config, 'setting.address', '');
    outPort = getValue(config, 'setting.port', 0);
    if (settingAddress == '' || outPort == 0) {
      throw '"address", "port" and "password" can not be empty in trojan setting.';
    }
    outAddress = Address(settingAddress);
  }

  @override
  Future<RRSSocket> newConnect(Link l) async {
    var res = Socks5Connect(
        rrsSocket: await connect(outAddress!.address, outPort!),
        link: l,
        outboundStruct: this);
    return res;
  }
}
