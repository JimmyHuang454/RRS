import 'dart:async';
import 'dart:typed_data';

import 'package:proxy/utils/const.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/utils/utils.dart';
import 'package:crypto/crypto.dart';
import 'package:proxy/outbounds/base.dart';
import 'package:proxy/inbounds/base.dart';

class TrojanConnect extends Connect {
  List<int> passwordSha224;

  final List<int> crlf = '\r\n'.codeUnits; // X'0D0A'
  bool isSendHeader = false;

  TrojanConnect(
      {required this.passwordSha224,
      required super.link,
      required super.rrsSocket,
      required super.outboundStruct});

  List<int> _buildRequest() {
    //{{{
    List<int> header, request;
    header = passwordSha224 + crlf;

    if (link.streamType == StreamType.tcp) {
      request = [1];
    } else {
      request = [3];
    }

    var addressType = link.targetAddress!.type;

    if (addressType == AddressType.domain) {
      request.add(3);
      request.add(link.targetAddress!.rawAddress.lengthInBytes);
    } else if (addressType == AddressType.ipv4) {
      request.add(1);
    } else {
      request.add(4);
    }
    request += link.targetAddress!.rawAddress;
    request += Uint8List(2)
      ..buffer.asByteData().setInt16(0, link.targetport, Endian.big);
    var res = header + request + crlf;
    return res;
  } //}}}

  List<int> _buildUDPHead(int payloadLen) {
    //{{{
    List<int> request = [];

    var addressType = link.targetAddress!.type;

    if (addressType == AddressType.domain) {
      request.add(3);
      request.add(link.targetAddress!.rawAddress.lengthInBytes);
    } else if (addressType == AddressType.ipv4) {
      request.add(1);
    } else {
      request.add(4);
    }
    request += link.targetAddress!.rawAddress;
    request += Uint8List(2)
      ..buffer.asByteData().setInt16(0, link.targetport, Endian.big);

    request += Uint8List(2)
      ..buffer.asByteData().setInt16(0, payloadLen, Endian.big);
    var res = request + crlf;
    return res;
  } //}}}

  @override
  void add(List<int> data) {
    if (link.streamType == StreamType.udp) {
      data = _buildUDPHead(data.length) + data;
    }

    if (!isSendHeader) {
      isSendHeader = true;
      data = _buildRequest() + data;
    }

    super.add(data);
  }
}

class TrojanOut extends OutboundStruct {
  String password = '';
  List<int> passwordSha224 = [];

  bool isBalancer = false;
  bool redirected = false;

  TrojanOut({required super.config})
      : super(protocolName: 'trojan', protocolVersion: '1') {
    password = getValue(config, 'setting.password', '');
    isBalancer = getValue(config, 'setting.balance.enable', false);

    var settingAddress = getValue(config, 'setting.address', '');
    outPort = getValue(config, 'setting.port', 0);
    if (settingAddress == '' || outPort == 0 || password == '') {
      throw '"address", "port" and "password" can not be empty in trojan setting.';
    }
    outAddress = Address(settingAddress);

    passwordSha224 = sha224.convert(password.codeUnits).toString().codeUnits;
  }

  @override
  Future<RRSSocket> newConnect(Link l) async {
    l.outAddress = outAddress!;
    l.outPort = outPort!;

    // unlike freeom, trojan has a fix address. so we can apply fastopen to it since it never change.
    var res = TrojanConnect(
        rrsSocket: await connect(outAddress!.address, outPort!),
        link: l,
        outboundStruct: this,
        passwordSha224: passwordSha224);
    return res;
  }
}
