import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/utils/utils.dart';

class HTMLWSClient extends TransportClient {
  late String path;
  late String userAgent;
  late html.WebSocket ws;
  late Map<String, String> header;

  HTMLWSClient({required super.config}) : super(protocolName: 'htmlws') {
    path = getValue(config, 'setting.path', '');
    // header = getValue(config, 'setting.header', {});
    // userAgent = getValue(config, 'setting.header', '');
  }

  @override
  Future<void> connect(host, int port) async {
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
    ws = html.WebSocket(address);

    var streamController = StreamController<int>();
    var w = StreamQueue<int>(streamController.stream);
    var o = ws.onOpen.listen(
      (event) {
        streamController.add(1);
      },
    );
    await w.next;
    await streamController.close();
    w.cancel();
    o.cancel();
  }

  @override
  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    clearListen();
    streamSubscription = ws.onMessage.listen((data) {
      onData!((data.data as ByteBuffer).asUint8List());
    });
    islisten = true;
  }

  Future<void> _close() async {
    clearListen();
    ws.close();
  }

  @override
  Future close() {
    return _close();
  }

  @override
  void add(List<int> data) {
    ws.sendByteBuffer(Uint8List.fromList(data).buffer);
  }

  @override
  InternetAddress get remoteAddress => InternetAddress('127.0.0.1');

  @override
  int get remotePort => 1;
}
