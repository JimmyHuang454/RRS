import 'dart:io';

import 'package:proxy/transport/client/ws.dart';
import 'package:proxy/transport/server/base.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/utils/utils.dart';

class WSRRSServerSocket extends RRSServerSocket {
  HttpServer httpServer;
  String path;

  WSRRSServerSocket({required this.httpServer, required this.path});

  @override
  Future<void> close() async {
    await httpServer.close();
  }

  @override
  void listen(void Function(RRSSocket event)? onData,
      {Function(dynamic e, dynamic s)? onError, void Function()? onDone}) {
    httpServer.listen((httpClient) async {
      if (path == '' || '/$path' == httpClient.uri.path || path == '/') {
        var wsSocket = await WebSocketTransformer.upgrade(httpClient);
        onData!(RRSSocketBase(rrsSocket: WSRRSSocket(webSocket: wsSocket)));
      } else {
        httpClient.response.close();
      }
    }, onError: onError, onDone: onDone, cancelOnError: true);
  }
}

class WSServer extends TransportServer {
  String? path;

  WSServer({required super.config}) : super(protocolName: 'ws') {
    path = getValue(config, 'setting.path', '');
  }

  @override
  Future<RRSServerSocket> bind(address, int port) async {
    var httpServer = await HttpServer.bind(address, port);
    return RRSServerSocketBase(
        rrsServerSocket:
            WSRRSServerSocket(httpServer: httpServer, path: path!));
  }
}
