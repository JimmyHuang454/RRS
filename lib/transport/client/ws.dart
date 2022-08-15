import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

import 'package:proxy/transport/client/base.dart';

class TCPClient extends TransportClient {
  String path;
  late WebSocket ws;
  Map<String, String> header;

  TCPClient({this.path = '/', this.header = const {}})
      : super(protocolName: 'ws');

  @override
  Future<SecureSocket> connect(host, int port, {Duration? timeout}) {
    var client = HttpClient(context: securityContext);
    return WebSocket.connect(host, headers: header, customClient: client).then(
      (value) {
        ws = value;
        return this;
      },
    );
  }

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return ws.listen(onData as void Function(dynamic event),
        onError: onError, onDone: onDone) as StreamSubscription<Uint8List>;
  }

  @override
  Future close() => ws.close();

  @override
  void add(List<int> data) => ws.add(data);

  @override
  void destroy() => ws.close();
}
