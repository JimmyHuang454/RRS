import 'dart:async';
import 'dart:typed_data';
import 'package:grpc/grpc.dart';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/grpc/grpc.pbgrpc.dart';
import 'package:proxy/utils/utils.dart';

class GRPCSocket extends RRSSocket {
  StreamController<Hunk> to;

  Stream<Hunk> from;

  GRPCSocket({required this.to, required this.from});

  @override
  void add(List<int> data) {
    to.add(Hunk(data: data));
  }

  @override
  void listen(void Function(Uint8List event)? onData,
      {Function(dynamic e, dynamic s)? onError, void Function()? onDone}) {
    from.listen((event) {
      onData!(Uint8List.fromList(event.data));
    }, onDone: onDone, onError: onError, cancelOnError: true);
  }

  @override
  void close() {
    to.close();
  }

  @override
  Future<dynamic> get done => to.done;
}

class GRPCClient extends TransportClient {
  ChannelCredentials? channelCredentials;
  ChannelOptions? channelOptions;
  GunServiceClient? gunServiceClient;
  String? serverName;

  GRPCClient({required super.config}) : super(protocolName: 'grpc') {
    if (useTLS!) {
      channelCredentials = ChannelCredentials.secure();
    } else {
      channelCredentials = ChannelCredentials.insecure();
    }
    var idleTimeout = getValue(config, 'idleTimeout', 10);
    var connectTime = getValue(config, 'connectTime', 10);
    channelOptions = ChannelOptions(
        credentials: channelCredentials!,
        idleTimeout: Duration(seconds: idleTimeout),
        // codecRegistry: CodecRegistry(codecs: const [GzipCodec(), IdentityCodec()]),
        connectionTimeout: Duration(seconds: connectTime));

    serverName = getValue(config, 'setting.serverName', 'GunService');
  }

  @override
  Future<RRSSocket> connect(host, int port) async {
    final contr = StreamController<Hunk>();
    var clientChannel =
        ClientChannel(host, port: port, options: channelOptions!);
    gunServiceClient = GunServiceClient(clientChannel, serverName: serverName!);
    var from = gunServiceClient!.tun(contr.stream);

    return RRSSocketBase(rrsSocket: GRPCSocket(to: contr, from: from));
  }
}
