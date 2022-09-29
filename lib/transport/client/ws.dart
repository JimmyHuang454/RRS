import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/utils/utils.dart';

class WS extends RRSSocket {
  WS({required super.socket});

  // WS is not a stream protocol,
  // it's closed when it close. So when we received onDone(), we should not add() and listen() to that WS channel.
  @override
  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    super.listen(onData, onDone: () {
      isClosed = true;
      onDone!();
    });
  }
}

class WSClient2 extends TransportClient1 {
  late String path;
  late String userAgent;
  late WebSocket ws;
  late Map<String, String> header;

  String outAddress = '';
  int outPort = 0;

  WSClient2({required super.config}) : super(protocolName: 'ws') {
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

    if (useTLS) {
      address = 'wss://$address';
    } else {
      address = 'ws://$address';
    }
    ws = await WebSocket.connect(address);

    outAddress = address;
    outPort = port;
    // return WS(socket: ws);
    return RRSSocket(socket: ws);
  }
}
