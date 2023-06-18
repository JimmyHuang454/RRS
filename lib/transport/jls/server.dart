import 'dart:async';
import 'dart:typed_data';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/jls/client.dart';
import 'package:proxy/transport/jls/format.dart';
import 'package:proxy/transport/jls/jls.dart';
import 'package:proxy/transport/jls/tls/base.dart';
import 'package:proxy/transport/server/base.dart';
import 'package:proxy/utils/utils.dart';

class JLSServerSocket extends RRSServerSocketBase {
  JLSHandShakeSide? local;

  JLSServerSocket({required super.rrsServerSocket}) {
    local = JLSHandShakeServer(
        pwdStr: '123', ivStr: '456', local: serverHelloHandshake);
  }

  bool isFallback = false;
  Completer isChecked = Completer();

  Future<bool> auth(RRSSocket client) async {
    client.listen((date) async {
      isFallback =
          !(await local!.check(inputRemote: ClientHello.parse(rawData: date)));
      isChecked.complete(true);
    }, onDone: () async {
      client.close();
    }, onError: (e, s) async {
      client.close();
    });
    await isChecked.future;
    if (isFallback) {
      // TODO:  pass to fallback website.
      return false;
    }
    await client.clearListen();
    client.add(await local!.build());
    return true;
  }

  @override
  void listen(void Function(RRSSocket event)? onData,
      {Function(dynamic e, dynamic s)? onError, void Function()? onDone}) {
    rrsServerSocket.listen((client) async {
      if (await auth(client)) {
        var res = JLSSocket(rrsSocket: client);
        res.local = local;
        onData!(res);
      }
    }, onDone: onDone, onError: onError);
  }
}
