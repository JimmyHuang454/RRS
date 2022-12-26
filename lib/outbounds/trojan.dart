import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/utils/utils.dart';
import 'package:crypto/crypto.dart';
import 'package:proxy/outbounds/base.dart';
import 'package:proxy/inbounds/base.dart';

class TrojanConnect extends Connect2 {
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
  } //}}}

  List<int> _buildUDPHead(int payloadLen) {
    //{{{
    List<int> request = [];

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

    request += Uint8List(2)
      ..buffer.asByteData().setInt16(0, payloadLen, Endian.big);
    var res = request + crlf;
    return res;
  } //}}}

  @override
  void add(List<int> data) {
    if (link.streamType == 'UDP') {
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
  late Link link;

  TrojanOut({required super.config})
      : super(protocolName: 'trojan', protocolVersion: '1') {
    password = getValue(config, 'setting.password', '');
    isBalancer = getValue(config, 'setting.balance.enable', false);

    if (outAddress == '' || outPort == 0 || password == '') {
      throw '"address", "port" and "password" can not be empty in trojan setting.';
    }

    passwordSha224 = sha224.convert(password.codeUnits).toString().codeUnits;
  }

  Future<void> handleBalance() async {
    //{{{
    if (!isBalancer) {
      realOutAddress = outAddress;
      realOutPort = outPort;
      return;
    }

    if (redirected) {
      return;
    }

    var params = {
      'password': passwordSha224,
      'config': getValue(config, 'setting.balance', {})
    };
    var url = Uri(host: outAddress, queryParameters: params);
    var response = await http.get(url);
    var balanceInfo = jsonDecode(response.body);
    realOutAddress = balanceInfo['realOutAddress'];
    realOutPort = balanceInfo['realOutPort'];
    if (balanceInfo.contains('testAddress')) {
      try {
        await http
            .get(balanceInfo['testAddress'])
            .timeout(Duration(seconds: 3));
      } catch (_) {
        throw "Balance server assign a node that can not be used. Please connect your service provider to fix this.";
      }
    }
  } //}}}

  @override
  Future<RRSSocket> newConnect(Link l) async {
    await handleBalance(); // init realOutAddress and realOutPort.

    var temp = await getClient().connect(realOutAddress, realOutPort);
    var res = TrojanConnect(
        rrsSocket: temp,
        link: l,
        outboundStruct: this,
        passwordSha224: passwordSha224);
    return res;
  }
}
