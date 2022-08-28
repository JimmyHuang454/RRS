import 'dart:async';
import 'dart:typed_data';
import 'package:async/async.dart';

import 'package:proxy/utils/utils.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/outbounds/base.dart';

class HTTPConnect extends Connect {
  HTTPConnect(
      {required super.transportClient,
      required super.outboundStruct,
      required super.link,
      required super.realOutAddress,
      required super.realOutPort});
}

class HTTPOut extends OutboundStruct {
  String userAccount = '';
  String userPassword = '';
  bool isBuildConnection = false;

  HTTPOut({required super.config})
      : super(protocolName: 'http', protocolVersion: '1.1') {
    userAccount = getValue(config, 'setting.account', '');
    userPassword = getValue(config, 'setting.password', '');

    if (outAddress == '' || outPort == 0) {
      throw '"address" and "port" can not be empty in http setting.';
    }
  }

  @override
  Future<Connect> newConnect(Link l) async {
    var conn = HTTPConnect(
        transportClient: newClient(),
        outboundStruct: this,
        link: l,
        realOutAddress: outAddress,
        realOutPort: outPort);
    if (l.method == 'CONNECT') {
      var streamController = StreamController<int>();
      var w = StreamQueue<int>(streamController.stream);
      conn.listen((data) {
        var pos = indexOfElements(data, '\r\n\r\n'.codeUnits);
        if (pos == -1) {
          streamController.add(0); // failed.
        } else {
          streamController.add(1); // created
        }
      }, onError: (e) {
        streamController.add(0);
      });
      conn.add(
          '${l.method} ${l.targetUri.toString()} ${l.protocolVersion}\r\n\r\n'
              .codeUnits);
      var res = await w.next;
      await w.cancel();
      await streamController.close();
      await conn.transportClient.clearListen();

      if (res != 1) {
        await conn.close();
        throw 'failed to build http tunnel.';
      }
    }
    return conn;
  }
}
