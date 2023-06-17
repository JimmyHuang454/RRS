import 'dart:async';
import 'dart:typed_data';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/jls/client.dart';
import 'package:proxy/transport/server/base.dart';

class JLSServerSocket extends RRSServerSocketBase {
  JLSServerSocket({required super.rrsServerSocket});

  @override
  void listen(void Function(RRSSocket event)? onData,
      {Function(dynamic e, dynamic s)? onError, void Function()? onDone}) {
    rrsServerSocket.listen((event) {
      onData!(event);
    }, onDone: onDone, onError: onError);
  }
}
