import 'dart:async';
import 'dart:typed_data';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/jls/format.dart';
import 'package:proxy/transport/jls/jls.dart';
import 'package:proxy/transport/jls/tls/base.dart';

class JLSSocket extends RRSSocketBase {
  //{{{
  late JLSHandShakeSide local;

  bool isCheck = false;

  Completer isConnected = Completer();

  JLSSocket({required super.rrsSocket}) {
    local = JLSHandShakeClient(
        pwdStr: '123', ivStr: '456', local: clientHelloHandshake);
  }

  void closeAndThrow(dynamic msg) {
    rrsSocket.close();
    throw Exception('[JLS] $msg.');
  }

  Future<void> secure() async {
    rrsSocket.listen((data) async {
      if (isCheck) {
      } else {
        if (!await local.checkServer(
            inputServerHello: ServerHello.parse(rawData: data))) {
          // TODO: handle it like normal tls1.3 client.
          closeAndThrow('wrong server response');
        }
        isConnected.complete(true);
      }
    }, onDone: () async {
      closeAndThrow('unexpected closed.');
    }, onError: (e, s) async {
      closeAndThrow(e);
    });

    rrsSocket.add(await local.build());

    var res = await isConnected.future.timeout(Duration(seconds: 3));
    if (!res) {
      closeAndThrow('timeout');
    }
    await rrsSocket.clearListen();
  }

  @override
  Future<void> add(List<int> data) async {
    var res = await local.send(data);
    rrsSocket.add(res.build());
  }

  @override
  void listen(Future<void> Function(Uint8List event)? onData,
      {Future<void> Function(dynamic e, dynamic s)? onError,
      Future<void> Function()? onDone}) {
    rrsSocket.listen((data) async {}, onDone: onDone, onError: onError);
  }
} //}}}
