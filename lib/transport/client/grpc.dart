import 'dart:async';
import 'dart:typed_data';
import 'package:grpc/grpc.dart';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/grpc/grpc.pbgrpc.dart';

class GRPCSocket extends RRSSocket {
  StreamController<StreamMsg> to;
  Stream<StreamMsg> from;

  GRPCSocket({required this.to, required this.from});

  @override
  void add(List<int> data) {
    to.add(StreamMsg(data: data));
  }

  @override
  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone, cancelOnError = true}) {
    from.listen((event) {
      onData!(Uint8List.fromList(event.data));
    }, onDone: onDone, onError: onError, cancelOnError: cancelOnError);
  }

  @override
  void close() {
    to.close();
  }

  @override
  Future<dynamic> get done => to.done;
}

class GRPCClient extends TransportClient {
  ClientChannel? clientChannel;
  ChannelCredentials? channelCredentials;
  ChannelOptions? channelOptions;
  RRSClient? rrsClient;

  GRPCClient({required super.config}) : super(protocolName: 'grpc') {
    if (useTLS!) {
      channelCredentials = ChannelCredentials.secure();
    } else {
      channelCredentials = ChannelCredentials.insecure();
    }
    channelOptions = ChannelOptions(credentials: channelCredentials!);
  }

  @override
  Future<RRSSocket> connect(host, int port) async {
    final contr = StreamController<StreamMsg>();
    clientChannel = ClientChannel(host, port: port, options: channelOptions!);
    rrsClient = RRSClient(clientChannel!);
    var from = rrsClient!.connect(contr.stream);

    return RRSSocketBase(rrsSocket: GRPCSocket(to: contr, from: from));
  }
}
