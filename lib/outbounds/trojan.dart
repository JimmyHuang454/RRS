import 'dart:async';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'package:proxy/utils/utils.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/outbounds/base.dart';

class TrojanOut extends OutboundStruct {
  String password = '';
  String userID = '';
  List<int> passwordSha224 = [];
  List<int> userIDSha224 = [];
  final List<int> ctrl = [0, 13, 0, 10];
  bool isAuth = false;
  late Link link;

  TrojanOut({required super.config})
      : super(protocolName: 'trojan', protocolVersion: '1') {
    password = getValue(config, 'setting.password', '');
    userID = getValue(config, 'setting.userID', '');

    if (outAddress == '' || outPort == 0 || password == '') {
      throw '"address", "port" and "password" can not be empty in trojan setting.';
    }
  }

  Future<List<int>> _buildRequest() async {
    if (passwordSha224.isEmpty) {
      var temp = await Sha224().hash(password.codeUnits);
      passwordSha224 = temp.bytes;
    }
    if (userID != '' && userIDSha224.isEmpty) {
      var temp2 = await Sha224().hash(password.codeUnits);
      userIDSha224 = temp2.bytes;
    }

    List<int> header, request;
    if (userIDSha224.isEmpty) {
      header = passwordSha224 + ctrl; // X'0D0A'
    } else {
      header = passwordSha224 + [0, 0, 0, 0] + userIDSha224;
    }

    if (link.method == 'CONNECT') {
      request = [5, 1, 0];
    } else {
      request = [5, 3, 0];
    }

    if (link.typeOfAddress == 'domain') {
      request.add(3);
      request.add(link.targetAddress.codeUnits.length);
    } else if (link.typeOfAddress == 'ipv4') {
      request.add(1);
    } else {
      request.add(4);
    }
    request += link.targetAddress.codeUnits;
    request += Uint8List(2)
      ..buffer.asByteData().setInt16(0, link.targetport, Endian.big);
    return header + request + ctrl;
  }

  @override
  void add(List<int> data) async {
    if (isAuth) {
      socket.add(data);
    } else {
      socket.add(await _buildRequest() + data);
      isAuth = true;
    }
  }
}
