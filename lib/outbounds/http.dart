import 'dart:async';
import 'dart:typed_data';
import 'package:proxy/transport/client/base.dart';

import 'package:proxy/utils/utils.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/outbounds/base.dart';

class HTTPConnect extends Connect {
  void Function(Uint8List event)? onD;
  Function(dynamic e, dynamic s)? onE;
  void Function()? onDo;
  String protocolVersion = 'HTTP/1.1';

  bool isConnected = false;

  HTTPConnect(
      {required super.link,
      required super.rrsSocket,
      required super.outboundStruct});

  // check before listen.
  Future<void> isNeedConnection() async {
    //{{{
    if (link.method != 'CONNECT') {
      return;
    }

    var isReceiveConnectionStatus = Completer<int>();
    rrsSocket.listen((data) {
      if (isConnected) {
        onD!(data);
      } else {
        var pos = indexOfElements(data, '\r\n\r\n'.codeUnits);
        if (pos == -1) {
          // failed.
          isReceiveConnectionStatus.complete(0);
        } else {
          // created
          isReceiveConnectionStatus.complete(1);
        }
      }
    }, onError: (e, s) {
      if (isConnected) {
        onE!(e, s);
      } else {
        // failed.
        isReceiveConnectionStatus.complete(0);
      }
    }, onDone: () {
      if (isConnected) {
        onDo!();
      }
    });
    rrsSocket.add(
        '${link.method} ${link.targetUri!.toString()} $protocolVersion\r\n\r\n'
            .codeUnits);
    var res = await isReceiveConnectionStatus.future;
    isConnected = true;

    if (res != 1) {
      rrsSocket.close();
      throw 'failed to build http tunnel.';
    }
  } //}}}

  @override
  void listen(void Function(Uint8List event)? onData,
      {Function(dynamic e, dynamic s)? onError, void Function()? onDone}) {
    if (isConnected) {
      // Limitation: can't cancel listen. So we redirect event.
      onD = onData;
      onE = onError;
      onDo = onDone;
    } else {
      super.listen(onData, onDone: onDone, onError: onError);
    }
  }
}

class HTTPOut extends OutboundStruct {
  String userAccount = '';
  String userPassword = '';
  bool isBuildConnection = false;

  HTTPOut({required super.config})
      : super(protocolName: 'http', protocolVersion: '1.1') {
    userAccount = getValue(config, 'setting.account', '');
    userPassword = getValue(config, 'setting.password', '');

    var settingAddress = getValue(config, 'setting.address', '');
    outPort = getValue(config, 'setting.port', 0);
    if (settingAddress == '' || outPort == 0) {
      throw '"address" and "port" can not be empty in http setting.';
    }
    outAddress = Address(settingAddress);
  }

  @override
  Future<RRSSocket> newConnect(Link l) async {
    l.outAddress = outAddress!;
    l.outPort = outPort!;

    var res = HTTPConnect(
        rrsSocket: await connect(outAddress!.address, outPort!),
        link: l,
        outboundStruct: this);
    await res.isNeedConnection();
    return res;
  }
}
