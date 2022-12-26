import 'dart:io';
import 'dart:async';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/utils/utils.dart';

class WSClient2 extends TransportClient {
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
    return RRSSocket(socket: ws);
  }
}
