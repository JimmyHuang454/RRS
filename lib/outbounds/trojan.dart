import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:proxy/utils/utils.dart';
import 'package:crypto/crypto.dart';
import 'package:proxy/outbounds/base.dart';
import 'package:proxy/inbounds/base.dart';

class TrojanOut extends OutboundStruct {
  String password = '';
  String userID = '';
  List<int> passwordSha224 = [];
  List<int> userIDSha224 = [];
  final List<int> crlf = '\r\n'.codeUnits; // X'0D0A'
  bool isSendHeader = false;
  bool isReceiveResponse = false;
  late Link link;

  TrojanOut({required super.config})
      : super(protocolName: 'trojan', protocolVersion: '1') {
    password = getValue(config, 'setting.password', '');
    userID = getValue(config, 'setting.userID', '');

    if (outAddress == '' || outPort == 0 || password == '') {
      throw '"address", "port" and "password" can not be empty in trojan setting.';
    }

    passwordSha224 = sha224.convert(password.codeUnits).toString().codeUnits;
    if (userID != '') {
      userIDSha224 = sha224.convert(userID.codeUnits).toString().codeUnits;
    }
  }

  List<int> _buildRequest() {
    List<int> header, request;
    if (userIDSha224.isEmpty) {
      header = passwordSha224 + crlf;
    } else {
      header = passwordSha224 + [0, 0, 0, 0] + userIDSha224 + crlf;
    }

    if (link.streamType == 'TCP') {
      request = [1];
    } else {
      request = [3];
    }

    if (link.targetAddress.type == 'domain') {
      request.add(3);
      request.add(link.targetAddress.rawAddress.lengthInBytes);
    } else if (link.targetAddress.type == 'ipv4') {
      request.add(1);
    } else {
      request.add(4);
    }
    request += link.targetAddress.rawAddress;
    request += Uint8List(2)
      ..buffer.asByteData().setInt16(0, link.targetport, Endian.big);
    var res = header + request + crlf;
    return res;
  }

  @override
  Future<void> connect(Link l) async {
    link = l;
    await transportClient.connect(outAddress, outPort);
  }

  @override
  void add(List<int> data) {
    if (isSendHeader) {
      super.add(data);
    } else {
      super.add(_buildRequest() + data);
      isSendHeader = true;
    }
  }
}
