import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:proxy/transport/client/base.dart';

class TCPRRSSocket extends RRSSocket {
  Socket socket;

  StreamSubscription<Uint8List>? streamSubscription;

  TCPRRSSocket({required this.socket});

  @override
  Future<dynamic>? get done => socket.done;

  @override
  Future<void> add(List<int> data) async {
    socket.add(data);
    // await socket.flush();
  }

  @override
  Future<void> close() async {
    // await socket.flush();
    socket.close();
  }

  @override
  Future<void> clearListen() async {
    if (streamSubscription != null) {
      await streamSubscription!.cancel();
    }
    streamSubscription = null;
  }

  @override
  void listen(Future<void> Function(Uint8List event)? onData,
      {Future<void> Function(dynamic e, dynamic s)? onError,
      Future<void> Function()? onDone}) {
    streamSubscription = socket.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: true);
  }
}

class TCPClient extends TransportClient {
  TCPClient({required super.config}) : super(protocolName: 'tcp');
}
