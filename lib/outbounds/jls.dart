import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:proxy/obj_list.dart';
import 'package:proxy/transport/jls/client.dart';
import 'package:proxy/transport/jls/jls.dart';
import 'package:proxy/transport/jls/tls/base.dart';
import 'package:proxy/utils/const.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/utils/utils.dart';
import 'package:proxy/outbounds/base.dart';
import 'package:proxy/inbounds/base.dart';

class JLSConnect extends Connect {
  final List<int> crlf = '\r\n'.codeUnits; // X'0D0A'
  bool isSendHeader = false;
  JLSClientHandler jlsClientHandler;
  final maxLen = 16384; // 2^14

  JLSConnect(
      {required super.link,
      required super.rrsSocket,
      required this.jlsClientHandler,
      required super.outboundStruct});

  List<int> _buildRequest() {
    //{{{
    List<int> request;

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
      ..buffer.asByteData().setUint16(0, link.targetport!, Endian.big);
    var res = request + crlf;
    return res;
  } //}}}

  @override
  Future<void> add(List<int> data) async {
    while (data.isNotEmpty) {
      List<int> res = [];
      if (data.length > maxLen) {
        res = data.sublist(0, maxLen);
        data = data.sublist(maxLen);
      } else {
        res = data;
        data = [];
      }
      await sendData(res);
    }
  }

  Future<void> sendData(List<int> data) async {
    if (!isSendHeader) {
      isSendHeader = true;
      data = _buildRequest() + data;
    }

    var res = (await jlsClientHandler.jls.send(data)).build();
    await super.add(res);
  }
}

class JLSOut extends OutboundStruct {
  String password = '';
  String fallback = '';
  String iv = '';
  Duration? timeout;

  JLSOut({required super.config})
      : super(protocolName: 'trojan', protocolVersion: '1') {
    password = getValue(config, 'setting.password', '');
    iv = getValue(config, 'setting.random', '');
    fallback = getValue(config, 'setting.fallback', 'apple.com');
    var sec = getValue(config, 'setting.timeout', 60);
    timeout = Duration(seconds: sec);

    var settingAddress = getValue(config, 'setting.address', '');
    outPort = getValue(config, 'setting.port', 0);
    if (settingAddress == '' || outPort == 0 || password == '' || iv == '') {
      throw Exception(
          '"password", "random", "address" can not be empty in setting.');
    }
    outAddress = Address(settingAddress);
  }

  @override
  Future<RRSSocket> newConnect(Link l) async {
    var jlsClient = JLSClient(
        pwdStr: password,
        ivStr: iv,
        fingerPrint: jlsFringerPrintList['default']!,
        servername: utf8.encode(fallback));

    var client = await connect(outAddress!.address, outPort!);
    var handler =
        JLSClientHandler(client: client, jls: jlsClient, jlsTimeout: timeout!);

    if (!await handler.secure()) {
      await client.close();
      throw Exception('failed to secure.');
    }

    var res = JLSConnect(
        rrsSocket: client,
        jlsClientHandler: handler,
        link: l,
        outboundStruct: this);
    return res;
  }
}
