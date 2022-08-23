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

  WSClient({required super.config}) : super(protocolName: 'ws') {
    path = getValue(config, 'setting.path', '');
    // header = getValue(config, 'setting.header', {});
    // userAgent = getValue(config, 'setting.header', '');
  }

  @override
  Future<SecureSocket> connect(host, int port) {
    var securityContext = SecurityContext(withTrustedRoots: useSystemRoot);
    var client = HttpClient(context: securityContext);
    var address = '';
    if (port == 443 || port == 80) {
      address = '$host/$path';
    } else {
      address = '$host:$port/$path';
    }
    client.badCertificateCallback = (cert, host, port) {
      return super.onBadCertificate(cert);
    };
    var tempDuration = Duration(seconds: connectionTimeout);
    client.connectionTimeout = tempDuration;
    // client.userAgent = userAgent;

    if (useTLS) {
      address = 'wss://$address';
    } else {
      address = 'ws://$address';
    }
    return WebSocket.connect(address).then(
      (value) {
        ws = value;
        return this;
      },
    );
  }

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    var controller = StreamController<Uint8List>();
    var temp = controller.stream;

    ws.listen((event) {
      controller.add(event);
    }, onDone: () {
      controller.close();
    }, onError: (e) {
      controller.addError(e);
    }, cancelOnError: true);

    var res = temp.listen((event) {
      onData!(event);
    }, onDone: () {
      onDone!();
    }, onError: (e) {
      onError!(e);
    }, cancelOnError: true);

    return res;
  }

  @override
  Future close() => ws.close();

  @override
  void add(List<int> data) => ws.add(data);

  @override
  void destroy() => ws.close();

  @override
  Future get done => ws.done;

  @override
  InternetAddress get remoteAddress => InternetAddress('127.0.0.1');

  @override
  int get remotePort => 1;
}
