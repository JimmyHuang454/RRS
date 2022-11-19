import 'dart:io';

import 'package:proxy/transport/client/h2.dart';
import 'package:proxy/transport/server/base.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/utils/utils.dart';

import 'package:http2/http2.dart';

class H2RRSServerScoket extends RRSServerSocket {
  String path;

  H2RRSServerScoket({super.serverSocket, required this.path});

  @override
  void listen(void Function(RRSSocket event)? onData,
      {Function? onError, void Function()? onDone}) {
    serverSocket.listen((socketClient) {
      var h2Client = ServerTransportConnection.viaSocket(socketClient);
      h2Client.incomingStreams.listen(
        (h2Client) {
          var s = RRSSocket(
              socket: H2Socket(
            transportStream: h2Client,
          ));
          onData!(s);
        },
      );
    }, onError: onError, onDone: onDone, cancelOnError: true);
  }
}

class H2Server extends TransportServer1 {
  late HttpServer httpServer;
  late String path;

  H2Server({required super.config}) : super(protocolName: 'h2') {
    path = getValue(config, 'setting.path', '');
  }

  @override
  Future<RRSServerSocket> bind(address, int port) async {
    httpServer = await HttpServer.bind(address, port);
    return H2RRSServerScoket(serverSocket: httpServer, path: path);
  }
}
