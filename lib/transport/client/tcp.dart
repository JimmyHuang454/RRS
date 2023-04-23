import 'dart:io';
import 'dart:typed_data';

import 'package:proxy/transport/client/base.dart';

class TCPRRSSocket extends RRSSocket {
  Socket socket;

  TCPRRSSocket({required this.socket});

  @override
  Future<dynamic>? get done => socket.done;

  @override
  void add(List<int> data) {
    socket.add(data);
  }

  @override
  void close() {
    socket.close();
  }

  @override
  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    socket.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: true);
  }
}

class TCPClient extends TransportClient {
  TCPClient({required super.config}) : super(protocolName: 'tcp');
}
