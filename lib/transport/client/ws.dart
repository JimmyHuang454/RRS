import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/utils/utils.dart';

class WSClient extends TransportClient {
  late String path;
  late String userAgent;
  late WebSocket ws;
  late Map<String, String> header;

  WSClient({
    required super.tag,
    required super.config,
  }) : super(protocolName: 'ws') {
    path = getValue(config, 'setting.path', '/');
    header = getValue(config, 'setting.header', {});
    userAgent = getValue(config, 'setting.header', '');
  }

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
