import 'dart:async';
import 'dart:typed_data';
import 'package:grpc/grpc.dart';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/grpc/grpc.pbgrpc.dart';
import 'package:proxy/utils/utils.dart';

class GRPCSocket extends RRSSocket {
  StreamController<Hunk> to;
  StreamSubscription<Hunk>? streamSubscription;

  Stream<Hunk> from;

  GRPCSocket({required this.to, required this.from});

  @override
  Future<void> add(List<int> data) async {
    to.add(Hunk(data: data));
  }

  @override
  Future<void> clearListen() async {
    if (streamSubscription != null) {
      await streamSubscription!.cancel();
    }
    streamSubscription = null;
  }

  @override
  void listen(void Function(Uint8List event)? onData,
      {Function(dynamic e, dynamic s)? onError, void Function()? onDone}) {
    streamSubscription = from.listen((event) {
      onData!(Uint8List.fromList(event.data));
    }, onDone: onDone, onError: onError, cancelOnError: true);
  }

  @override
  Future<void> close() async {
    await to.close();
  }

  @override
  Future<dynamic> get done => to.done;
}

class GRPCClient extends TransportClient {
  ChannelCredentials? channelCredentials;
  ChannelOptions? channelOptions;
  GunServiceClient? gunServiceClient;
  String? serverName;
  Duration? idleTimeout;
  Duration? connectTime;

  GRPCClient({required super.config}) : super(protocolName: 'grpc') {
    if (useTLS!) {
      channelCredentials = ChannelCredentials.secure();
    } else {
      channelCredentials = ChannelCredentials.insecure();
    }
    // idleTimeout = getValue(config, 'idleTimeout', 3);
    // connectTime = getValue(config, 'connectTime', 1);

    idleTimeout = Duration(seconds: 50);
    connectTime = Duration(seconds: 50);

    serverName = getValue(config, 'setting.serviceName', 'GunService');
  }

  @override
  Future<RRSSocket> connect(host, int port, {dynamic sourceAddress}) async {
    final contr = StreamController<Hunk>();

    channelOptions = ChannelOptions(
        credentials: channelCredentials!,
        idleTimeout: idleTimeout!,
        codecRegistry:
            CodecRegistry(codecs: const [GzipCodec(), IdentityCodec()]),
        connectionTimeout: connectTime!);

    var clientChannel =
        ClientChannel(host, port: port, options: channelOptions!);
    gunServiceClient = GunServiceClient(clientChannel, serverName: serverName!);
    var from = gunServiceClient!.tun(contr.stream);
    return RRSSocketBase(rrsSocket: GRPCSocket(to: contr, from: from));
  }
}
