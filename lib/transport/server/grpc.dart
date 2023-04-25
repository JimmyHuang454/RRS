import 'dart:async';

import 'package:grpc/grpc.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/server/base.dart';
import 'package:proxy/transport/client/grpc.dart';

import 'package:proxy/transport/grpc/grpc.pbgrpc.dart';
import 'package:proxy/utils/utils.dart';

class GRPCServerScoket extends RRSServerSocket {
  StreamController<RRSSocket> streamController;
  Server server;

  GRPCServerScoket({required this.server, required this.streamController});

  @override
  Future<void> close() async {
    await server.shutdown();
  }

  @override
  void listen(void Function(RRSSocket event)? onData,
      {Function? onError, void Function()? onDone}) {
    streamController.stream.listen((data) {
      onData!(data);
    }, onError: onError, onDone: onDone, cancelOnError: true);
  }
}

class RRSService extends GunServiceBase {
  StreamController<RRSSocket> streamController;

  String serverName;

  @override
  String get $name => serverName;

  RRSService({required this.streamController, required this.serverName});

  @override
  Stream<Hunk> tun(ServiceCall call, Stream<Hunk> request) {
    final contr = StreamController<Hunk>();
    streamController
        .add(RRSSocketBase(rrsSocket: GRPCSocket(to: contr, from: request)));
    return contr.stream;
  }
}

class GRPCServer extends TransportServer {
  String? serverName;

  GRPCServer({required super.config}) : super(protocolName: 'grpc') {
    serverName = getValue(config, 'setting.serverName', 'GunService');
  }

  @override
  Future<RRSServerSocket> bind(address, int port) async {
    var streamController = StreamController<RRSSocket>();

    var service = [
      RRSService(streamController: streamController, serverName: serverName!)
    ];
    var server = Server(service);
    await server.serve(address: address, port: port);
    return GRPCServerScoket(server: server, streamController: streamController);
  }
}
