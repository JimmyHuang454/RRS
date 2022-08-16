import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

import 'package:proxy/transport/client/base.dart';

class WSClient extends TransportClient {
  String path;
  String userAgent;
  late WebSocket ws;
  Map<String, String> header;

  WSClient(
      {this.path = '/',
      this.header = const {},
      this.userAgent = '',
      super.useTLS,
      super.allowInsecure,
      super.timeout2,
      super.useSystemRoot})
      : super(protocolName: 'ws');

  @override
  Future<SecureSocket> connect(host, int port, {Duration? timeout}) {
    if (useTLS) {
      var securityContext = SecurityContext(withTrustedRoots: useSystemRoot);
      var client = HttpClient(context: securityContext);
      client.badCertificateCallback = (cert, host, port) {
        return super.onBadCertificate(cert);
      };
      client.connectionTimeout = timeout;
      client.keyLog = keyLog;
      client.userAgent = userAgent;
      return WebSocket.connect(host, headers: header, customClient: client)
          .then(
        (value) {
          ws = value;
          return this;
        },
      );
    } else {
      return WebSocket.connect(host, headers: header).then(
        (value) {
          ws = value;
          return this;
        },
      );
    }
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
