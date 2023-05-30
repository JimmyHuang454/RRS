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
      streamSubscription!.pause();
      onData!(Uint8List.fromList(event.data));
      streamSubscription!.resume();
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
    idleTimeout = Duration(seconds: getValue(config, 'idleTimeout', 10));
    connectTime = Duration(seconds: getValue(config, 'connectionTimeout', 1));
    channelOptions = ChannelOptions(
        credentials: channelCredentials!,
        idleTimeout: idleTimeout!,
        codecRegistry:
            CodecRegistry(codecs: const [GzipCodec(), IdentityCodec()]),
        connectionTimeout: connectTime!);

    serverName = getValue(config, 'setting.serviceName', 'GunService');
  }

  @override
  Future<RRSSocket> connect(host, int port,
      {dynamic sourceAddress, String sni = ""}) async {
    final contr = StreamController<Hunk>();

    var clientChannel =
        ClientChannel(host, port: port, options: channelOptions!);
    gunServiceClient = GunServiceClient(clientChannel, serverName: serverName!);
    var from = gunServiceClient!.tun(contr.stream);
    return RRSSocketBase(rrsSocket: GRPCSocket(to: contr, from: from));
  }
}
