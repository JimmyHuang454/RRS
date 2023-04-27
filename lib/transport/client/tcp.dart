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
  void add(List<int> data) {
    socket.add(data);
  }

  @override
  Future<void> close() async {
    await clearListen();
    await socket.close();
  }

  @override
  Future<void> clearListen() async {
    if (streamSubscription != null) {
      await streamSubscription!.cancel();
    }
    streamSubscription = null;
  }

  @override
  void listen(void Function(Uint8List event)? onData,
      {Function(dynamic e, dynamic s)? onError, void Function()? onDone}) {
    streamSubscription = socket.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: true);
  }
}

class TCPClient extends TransportClient {
  TCPClient({required super.config}) : super(protocolName: 'tcp');
}
