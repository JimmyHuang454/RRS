import 'dart:io';

import 'package:proxy/transport/client/ws.dart';
import 'package:proxy/transport/server/base.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/utils/utils.dart';

class TCPRRSServerSocket extends RRSServerSocket {
  HttpServer httpServer;
  String path;

  TCPRRSServerSocket({required this.httpServer, required this.path});

  @override
  Future<void> close() async {
    await httpServer.close();
  }

  @override
  void listen(void Function(RRSSocket event)? onData,
      {Function? onError, void Function()? onDone}) {
    httpServer.listen((httpClient) async {
      if (path == '' || '/$path' == httpClient.uri.path || path == '/') {
        var wsSocket = await WebSocketTransformer.upgrade(httpClient);
        onData!(RRSSocketBase(rrsSocket: WSRRSSocket(socket: wsSocket)));
      } else {
        httpClient.response.close();
      }
    }, onError: onError, onDone: onDone, cancelOnError: true);
  }
}

class WSServer extends TransportServer {
  late HttpServer httpServer;
  String? path;

  WSServer({required super.config}) : super(protocolName: 'ws') {
    path = getValue(config, 'setting.path', '');
  }

  @override
  Future<RRSServerSocket> bind(address, int port) async {
    httpServer = await HttpServer.bind(address, port);
    return TCPRRSServerSocket(httpServer: httpServer, path: path!);
  }
}
