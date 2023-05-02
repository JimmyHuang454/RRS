import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/utils/utils.dart';

class WSRRSSocket extends RRSSocket {
  WebSocket webSocket;
  StreamSubscription<dynamic>? streamSubscription;

  WSRRSSocket({required this.webSocket});

  @override
  Future<void> clearListen() async {
    if (streamSubscription != null) {
      await streamSubscription!.cancel();
    }
    streamSubscription = null;
  }

  @override
  Future<dynamic>? get done => webSocket.done;

  @override
  void add(List<int> data) {
    webSocket.add(data);
  }

  @override
  Future<void> close() async {
    await webSocket.close();
  }

  @override
  void listen(void Function(Uint8List event)? onData,
      {Function(dynamic e, dynamic s)? onError, void Function()? onDone}) {
    streamSubscription = webSocket.listen((data) {
      onData!(data as Uint8List);
    }, onError: onError, onDone: onDone, cancelOnError: true);
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
    return RRSSocketBase(rrsSocket: WSRRSSocket(webSocket: ws));
  }
}
