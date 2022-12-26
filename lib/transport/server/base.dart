import 'dart:async';
import 'dart:io';
import 'package:proxy/utils/utils.dart';
import 'package:proxy/transport/client/base.dart';

class RRSServerSocket {
  //{{{
  dynamic serverSocket;
  List<dynamic> streamSubscription = [];

  RRSServerSocket({required this.serverSocket});

  void close() async {
    await serverSocket.close();
  }

  void clearListen() async {
    for (var i = 0, len = streamSubscription.length; i < len; ++i) {
      await streamSubscription[i].cancel();
    }
    streamSubscription = [];
  }

  void listen(void Function(RRSSocket event)? onData,
      {Function? onError, void Function()? onDone}) {
    runZonedGuarded(() {
      var temp = serverSocket.listen((client) {
        onData!(RRSSocket(socket: client));
      }, onError: onError, onDone: onDone, cancelOnError: true);

      streamSubscription.add(temp);
    }, (e, s) {
      devPrint('server: $s');
      onError!(e);
    });
  }
} //}}}

class TransportServer {
  //{{{
  String protocolName;
  String tag = '';
  Map<String, dynamic> config;

  late bool useTLS;
  late bool requireClientCertificate;
  late List<String> supportedProtocols;
  late SecurityContext securityContext;

  late bool isMux;
  late String muxPassword;

  TransportServer({
    required this.protocolName,
    required this.config,
  }) {
    tag = getValue(config, 'tag', '');
    useTLS = getValue(config, 'tls.enabled', false);
    requireClientCertificate =
        getValue(config, 'tls.requireClientCertificate', true);
    supportedProtocols = getValue(config, 'tls.supportedProtocols', ['']);
    // securityContext = SecurityContext(withTrustedRoots: useTLS);

    isMux = getValue(config, 'mux.enabled', false);
    muxPassword = getValue(config, 'mux.password', '');
  }

  Future<RRSServerSocket> bind(address, int port) async {
    dynamic serverSocket;
    if (useTLS) {
      serverSocket = await SecureServerSocket.bind(
          address, port, securityContext,
          shared: false);
    } else {
      serverSocket = await ServerSocket.bind(address, port, shared: false);
    }

    return RRSServerSocket(serverSocket: serverSocket);
  }
} //}}}
