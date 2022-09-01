import 'dart:io';

import 'package:proxy/transport/client/ws.dart';
import 'package:proxy/transport/server/base.dart';
import 'package:proxy/transport/client/base.dart';

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
      var temp = WSClient(config: {});
      temp.load(await WebSocketTransformer.upgrade(httpClient));
      onData!(temp);
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
