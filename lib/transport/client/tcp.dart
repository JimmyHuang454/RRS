import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/utils/utils.dart';

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
    runZonedGuarded(() {
      socket.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: true);
    }, ((e, s) {
      onError!(e, s);
      devPrint(e);
    }));
  }
}

class TCPClient extends TransportClient {
  TCPClient({required super.config}) : super(protocolName: 'tcp');
}
