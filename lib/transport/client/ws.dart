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
  Future<void> add(List<int> data) async {
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
  Future<RRSSocket> connect(host, int port,
      {dynamic sourceAddress, String sni = ""}) async {
    var address = '';
    var scheme = 'ws';
    if (useTLS!) {
      scheme = 'wss';
    }
    address = '$scheme://$host:$port/$path';

    HttpClient client = HttpClient()
      ..connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) async {
        if (sni == "") {
          sni = uri.host;
        }
        var so = Socket.connect(uri.host, uri.port,
            sourceAddress: sourceAddress, timeout: timeout);
        ConnectionTask2<Socket> task;

        if (uri.isScheme('HTTPS')) {
          task = ConnectionTask2<Socket>(
              socket2: SecureSocket.secure(await so, host: sni));
        } else {
          task = ConnectionTask2<Socket>(socket2: so);
        }

        return Future(
          () => task,
        );
      };

    var ws = await WebSocket.connect(address, customClient: client);

    outAddress = address;
    outPort = port;
    return RRSSocketBase(rrsSocket: WSRRSSocket(webSocket: ws));
  }
}
