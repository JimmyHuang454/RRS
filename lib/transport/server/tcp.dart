import 'dart:async';
import 'dart:io';

import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/transport/server/base.dart';
import 'package:proxy/transport/client/base.dart';

class TCPRRSServerSocket extends RRSServerSocket {
  ServerSocket serverSocket;

  TCPRRSServerSocket({required this.serverSocket});

  @override
  Future<void> close() async {
    await serverSocket.close();
  }

  @override
  void listen(void Function(RRSSocket event)? onData,
      {Function(dynamic e, dynamic s)? onError, void Function()? onDone}) {
    serverSocket.listen((event) {
      onData!(RRSSocketBase(rrsSocket: TCPRRSSocket(socket: event)));
    }, onDone: onDone, onError: onError, cancelOnError: true);
  }
}

class TCPServer extends TransportServer {
  TCPServer({required super.config}) : super(protocolName: 'tcp');
}
