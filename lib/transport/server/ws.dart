import 'dart:io';
import 'dart:typed_data';

import 'package:proxy/transport/server/base.dart';
import 'package:proxy/transport/client/base.dart';

class WSServerClient extends TransportClient {
  WebSocket ws;

  WSServerClient({required this.ws}) : super(protocolName: 'ws', config: {});

  @override
  Future<void> connect(host, int port) async {}

  @override
  void add(List<int> data) {
    ws.add(data);
  }

  @override
  Future<void> close() async {
    await clearListen();
    await ws.close();
  }

  @override
  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    var temp = ws.listen(
        (data) {
          onData!(data as Uint8List);
        },
        onError: onError,
        onDone: () async {
          await clearListen();
          onDone!();
        },
        cancelOnError: true);

    streamSubscription.add(temp);
  }

  @override
  Future get done => ws.done;
}

class WSServer extends TransportServer {
  WSServer({required super.config}) : super(protocolName: 'ws');

  late HttpServer httpServer;

  @override
  Future<void> bind(address, int port) async {
    httpServer = await HttpServer.bind(address, port);
  }

  @override
  Future<void> close() async {
    await clearListen();
    await httpServer.close(force: true);
  }

  @override
  void listen(void Function(TransportClient event)? onData,
      {Function? onError, void Function()? onDone}) {
    var l = httpServer.listen((httpClient) async {
      var temp = await WebSocketTransformer.upgrade(httpClient);
      onData!(WSServerClient(ws: temp));
    }, onError: onError, onDone: onDone, cancelOnError: true);
    streamSubscription.add(l);
  }
}
