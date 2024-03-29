import 'dart:async';
import 'dart:typed_data';
import 'package:proxy/transport/client/base.dart';

import 'package:proxy/utils/utils.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/outbounds/base.dart';

class HTTPConnect extends Connect {
  Future<void> Function(Uint8List event)? onD;
  Future<void> Function(dynamic e, dynamic s)? onE;
  Future<void> Function()? onDo;
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
    rrsSocket.listen((data) async {
      if (isConnected) {
        await onD!(data);
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
    }, onError: (e, s) async {
      if (isConnected) {
        await onE!(e, s);
      } else {
        // failed.
        isReceiveConnectionStatus.complete(0);
      }
    }, onDone: () async {
      if (isConnected) {
        await onDo!();
      }
    });
    await super.add(
        '${link.method} ${link.targetUri!.toString()} $protocolVersion\r\n\r\n'
            .codeUnits);
    var res = await isReceiveConnectionStatus.future;
    isConnected = true;

    if (res != 1) {
      await super.close();
      throw 'failed to build http tunnel.';
    }
  } //}}}

  @override
  void listen(Future<void> Function(Uint8List event)? onData,
      {Future<void> Function(dynamic e, dynamic s)? onError,
      Future<void> Function()? onDone}) {
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
    var res = HTTPConnect(
        rrsSocket: await connect(outAddress!.address, outPort!),
        link: l,
        outboundStruct: this);
    await res.isNeedConnection();
    return res;
  }
}
