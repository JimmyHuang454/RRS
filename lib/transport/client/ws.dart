import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/utils/utils.dart';

class WSClient extends TransportClient {
  late String path;
  late String userAgent;
  late WebSocket ws;
  late Map<String, String> header;

  String outAddress = '';
  int outPort = 0;

  WSClient({required super.config}) : super(protocolName: 'ws') {
    path = getValue(config, 'setting.path', '');
    // header = getValue(config, 'setting.header', {});
    // userAgent = getValue(config, 'setting.header', '');
  }

  @override
  Future<void> connect(host, int port) async {
    outAddress = host;
    outPort = port;

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
  }

  @override
  void load(s) {
    ws = s;
  }

  @override
  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    var temp = ws.listen((data) {
      onData!(data);
    }, onError: onError, onDone: onDone, cancelOnError: true);

    ws.done.then((value) {
      if (onDone != null) {
        onDone();
      }
    }, onError: (e) {
      if (onError != null) {
        onError(e);
      }
    });
    streamSubscription.add(temp);
  }

  @override
  Future close() async {
    return await ws.close();
  }

  @override
  void add(List<int> data) {
    ws.add(data);
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
    return RRSSocket(socket: ws);
  }
}
