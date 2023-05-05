import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/utils/utils.dart';

class ConnectionTask2<S> implements ConnectionTask<S> {
  @override
  Future<S> get socket => socket2;

  Future<S> socket2;
  // final void Function() _onCancel;

  ConnectionTask2({required this.socket2});

  @override
  void cancel() {}
}

class WSRRSSocket extends RRSSocket {
  WebSocket webSocket;
  StreamSubscription<dynamic>? streamSubscription;

  WSRRSSocket({required this.webSocket});

  @override
  Future<void> clearListen() async {
    if (streamSubscription != null) {
      await streamSubscription!.cancel();
    }
    streamSubscription = null;
  }

  @override
  Future<dynamic>? get done => webSocket.done;

  @override
  void add(List<int> data) {
    webSocket.add(data);
  }

  @override
  Future<void> close() async {
    await webSocket.close();
  }

  @override
  void listen(void Function(Uint8List event)? onData,
      {Function(dynamic e, dynamic s)? onError, void Function()? onDone}) {
    streamSubscription = webSocket.listen((data) {
      onData!(data as Uint8List);
    }, onError: onError, onDone: onDone, cancelOnError: true);
  }
}

class WSClient extends TransportClient {
  String? path;
  Map<String, String>? header;

  String outAddress = '';
  int outPort = 0;

  WSClient({required super.config}) : super(protocolName: 'ws') {
    path = getValue(config, 'setting.path', '');
  }

  @override
  Future<RRSSocket> connect(host, int port, {dynamic sourceAddress}) async {
    var address = '';
    var scheme = 'ws';
    if (useTLS!) {
      scheme = 'wss';
    }
    address = '$scheme://$host:$port/$path';

    HttpClient client = HttpClient()
      ..connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) async {
        if (uri.isScheme('HTTPS')) {
          var so = await Socket.connect(uri.host, uri.port,
              sourceAddress: sourceAddress);
          var test = ConnectionTask2<Socket>(
              socket2: SecureSocket.secure(so, host: uri.host));

          return Future(
            () => test,
          );
        }
        return Socket.startConnect(uri.host, uri.port,
            sourceAddress: sourceAddress);
      };

    var ws = await WebSocket.connect(address, customClient: client);

    outAddress = address;
    outPort = port;
    return RRSSocketBase(rrsSocket: WSRRSSocket(webSocket: ws));
  }
}
