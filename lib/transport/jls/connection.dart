import 'dart:async';
import 'dart:typed_data';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/jls/format.dart';
import 'package:proxy/transport/jls/jls.dart';
import 'package:proxy/transport/jls/tls/base.dart';

class JLSSocket extends RRSSocketBase {
  //{{{
  late JLSHandShakeClient client;
  Future<void> Function(Uint8List event)? onData2;
  Future<void> Function(dynamic e, dynamic s)? onError2;
  Future<void> Function()? onDone2;

  bool isCheck = false;

  Completer isConnected = Completer();
  late AppData appData;

  JLSSocket({required super.rrsSocket}) {
    client = JLSHandShakeClient(
        pwdStr: '123', ivStr: '456', format: clientHelloHandshake);
  }

  void closeAndThrow(dynamic msg) {
    rrsSocket.close();
    if (onError2 != null) {
      onError2!(msg, '');
    }
    throw Exception('[JLS] $msg.');
  }

  Future<void> secure() async {
    client.build();
    rrsSocket.listen((data) async {
      if (!isCheck) {
        if (!await client.checkServer(
            inputServerHello: ServerHello.parse(rawData: data))) {
          // TODO: handle it like normal tls1.3
          closeAndThrow('wrong server response');
        }
        isConnected.complete(true);
      } else {
        var res = await client.receive(ApplicationData.parse(rawData: data));
        onData2!(Uint8List.fromList(res));
      }
    }, onDone: onDone2, onError: onError2);
    rrsSocket.add(await client.build());
    var res = await isConnected.future.timeout(Duration(seconds: 3));
    if (!res) {
      closeAndThrow('timeout');
    }
  }

  @override
  Future<void> add(List<int> data) async {
    var res = await client.send(data);
    rrsSocket.add(res.build());
  }

  @override
  void listen(Future<void> Function(Uint8List event)? onData,
      {Future<void> Function(dynamic e, dynamic s)? onError,
      Future<void> Function()? onDone}) {
    onData2 = onData;
    onError2 = onError;
    onDone2 = onDone;
  }
} //}}}
