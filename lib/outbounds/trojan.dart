import 'dart:async';
import 'dart:typed_data';

import 'package:proxy/utils/utils.dart';
import 'package:crypto/crypto.dart';
import 'package:proxy/outbounds/base.dart';

class TrojanOut extends OutboundStruct {
  String password = '';
  String userID = '';
  List<int> passwordSha224 = [];
  List<int> userIDSha224 = [];
  List<int> response = [];
  final List<int> ctrl = [0, 13, 0, 10];
  bool isSendHeader = false;
  bool isReceiveResponse = false;

  TrojanOut({required super.config})
      : super(protocolName: 'trojan', protocolVersion: '1') {
    password = getValue(config, 'setting.password', '');
    userID = getValue(config, 'setting.userID', '');

    if (outAddress == '' || outPort == 0 || password == '') {
      throw '"address", "port" and "password" can not be empty in trojan setting.';
    }

    passwordSha224 = sha224.convert(password.codeUnits).bytes;
    if (userID != '') {
      userIDSha224 = sha224.convert(userID.codeUnits).bytes;
    }
  }

  Future<List<int>> _buildRequest() async {
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
    if (isSendHeader) {
      socket.add(data);
    } else {
      socket.add(await _buildRequest() + data);
      isSendHeader = true;
    }
  }

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return socket.listen((data) {
      if (isReceiveResponse) {
        onData!(data);
      } else {
        response += data;

        if (response.length < 5) {
          return;
        }

        if (response[1] != 0) {
          // handle error.
        }

        if (link.method != 'CONNECT') {
          // TODO: handle udp.
        }
        var atyp = response[3];
        var responseLength = 6;
        if (atyp == 1) {
          // ipv4
          responseLength += 4;
        } else if (atyp == 3) {
          // domain
          responseLength += response[4] + 1;
        } else {
          // ipv6
          responseLength += 16;
        }
        response = response.sublist(responseLength);
        isReceiveResponse = true;
        onData!(Uint8List.fromList(response));
        response = [];
      }
    }, onError: onError, onDone: onDone);
  }
}
