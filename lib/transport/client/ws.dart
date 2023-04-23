import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/utils/utils.dart';

class WSRRSSocket extends RRSSocket {
  WebSocket socket;

  WSRRSSocket({required this.socket});

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
    socket.listen(onData as dynamic,
        onError: onError, onDone: onDone, cancelOnError: true);
  }
}

class WSClient extends TransportClient {
  String? path;
  Map<String, String>? header;

  String outAddress = '';
  int outPort = 0;

  WSClient({required super.config}) : super(protocolName: 'ws') {
    path = getValue(config, 'setting.path', '');
  }

  @override
  Future<RRSSocket> connect(host, int port) async {
    var address = '';
    if (port == 443 || port == 80) {
      address = '$host/$path';
    } else {
      address = '$host:$port/$path';
    }

    if (useTLS!) {
      address = 'wss://$address';
    } else {
      address = 'ws://$address';
    }
    var ws = await WebSocket.connect(address);

    outAddress = address;
    outPort = port;
    return WSRRSSocket(socket: ws);
  }
}
