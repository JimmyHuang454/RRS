import 'dart:io';

import 'package:proxy/transport/server/base.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/utils/utils.dart';

class WSRRSServerScoket extends RRSServerSocket {
  String path;

  WSRRSServerScoket({super.serverSocket, required this.path});

  @override
  void listen(void Function(RRSSocket event)? onData,
      {Function? onError, void Function()? onDone}) {
    var temp = (serverSocket as HttpServer).listen((httpClient) async {
      if (path == '' || '/$path' == httpClient.uri.path) {
        onData!(
            RRSSocket(socket: await WebSocketTransformer.upgrade(httpClient)));
      } else {
        httpClient.response.close();
      }
    }, onError: onError, onDone: onDone, cancelOnError: true);
    streamSubscription.add(temp);
  }
}

class WSServer1 extends TransportServer1 {
  late HttpServer httpServer;
  late String path;

  WSServer1({required super.config}) : super(protocolName: 'ws') {
    path = getValue(config, 'setting.path', '');
  }

  @override
  Future<RRSServerSocket> bind(address, int port) async {
    httpServer = await HttpServer.bind(address, port);
    return WSRRSServerScoket(serverSocket: httpServer, path: path);
  }
}
