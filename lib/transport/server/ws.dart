import 'dart:io';
import 'dart:typed_data';

import 'package:proxy/transport/server/base.dart';
import 'package:proxy/transport/client/base.dart';

class WSServerClient extends TransportClient {
  WebSocket ws;
  HttpServer httpServer;

  WSServerClient({required this.ws, required this.httpServer})
      : super(protocolName: 'ws', config: {});

  @override
  void add(List<int> data) {
    ws.add(data);
  }

  @override
  Future<void> close() async {
    await ws.close();
  }

  @override
  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    var temp = ws.listen((data) {
      onData!(data as Uint8List);
    }, onError: onError, onDone: onDone, cancelOnError: true);

    streamSubscription.add(temp);
  }

  @override
  Future get done => ws.done;

  @override
  InternetAddress get remoteAddress => httpServer.address;

  @override
  int get remotePort => httpServer.port;
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
    await httpServer.close(force: true);
  }

  @override
  void listen(void Function(TransportClient event)? onData,
      {Function? onError, void Function()? onDone}) {
    var l = httpServer.listen((httpClient) async {
      onData!(WSServerClient(
          ws: await WebSocketTransformer.upgrade(httpClient),
          httpServer: httpServer));
    }, onError: onError, onDone: onDone, cancelOnError: true);
    streamSubscription.add(l);
  }

  @override
  int get port {
    return httpServer.port;
  }

  @override
  InternetAddress get address {
    return httpServer.address;
  }
}
