import 'dart:async';
import 'dart:typed_data';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/jls/format.dart';
import 'package:proxy/transport/jls/jls.dart';
import 'package:proxy/transport/jls/tls/base.dart';
import 'package:proxy/utils/utils.dart';

class JLSSocket extends RRSSocketBase {
  //{{{
  JLSHandShakeSide? local;

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
      if (await local!.check(inputRemote: ServerHello.parse(rawData: data))) {
        isConnected.complete(true);
      } else {
        // TODO: handle it like normal tls1.3 client.
        closeAndThrow('wrong server response');
      }
    }, onDone: () async {
      closeAndThrow('unexpected closed.');
    }, onError: (e, s) async {
      closeAndThrow(e);
    });

    var clientHello = await local!.build();
    rrsSocket.add(clientHello);

    var res = await isConnected.future.timeout(Duration(seconds: 3));
    if (!res) {
      closeAndThrow('timeout');
    }
    await rrsSocket.clearListen();
  }

  @override
  Future<void> add(List<int> data) async {
    var res = (await local!.send(data)).build();
    rrsSocket.add(res);
  }

  @override
  void listen(Future<void> Function(Uint8List event)? onData,
      {Future<void> Function(dynamic e, dynamic s)? onError,
      Future<void> Function()? onDone}) {
    rrsSocket.listen((data) async {
      var realData = await local!.receive(ApplicationData.parse(rawData: data));
      if (realData.isEmpty) {
        // TODO: unexpected msg.
        return;
      }
      onData!(Uint8List.fromList(realData));
    }, onDone: onDone, onError: onError);
  }
} //}}}
