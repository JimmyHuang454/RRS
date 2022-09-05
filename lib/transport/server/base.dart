import 'dart:async';
import 'dart:io';
import 'package:proxy/utils/utils.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/client/tcp.dart';

class TransportServer {
  //{{{
  String protocolName;
  String tag = '';
  Map<String, dynamic> config;

  late ServerSocket serverSocket;
  late SecureServerSocket secureServerSocket;

  // TLS
  late bool useTLS;
  late bool requireClientCertificate;
  late List<String> supportedProtocols;
  late SecurityContext securityContext;

  List<dynamic> streamSubscription = [];

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
  }

  Future<void> bind(address, int port) async {
    if (useTLS) {
      secureServerSocket = await SecureServerSocket.bind(
          address, port, securityContext,
          requireClientCertificate: requireClientCertificate,
          supportedProtocols: supportedProtocols,
          shared: false);
    } else {
      serverSocket = await ServerSocket.bind(address, port, shared: false);
    }
  }

  Future<void> close() async {
    if (useTLS) {
      await secureServerSocket.close();
    } else {
      await serverSocket.close();
    }
  }

  Future<void> clearListen() async {
    for (var i = 0, len = streamSubscription.length; i < len; ++i) {
      await streamSubscription[i].cancel();
    }
    streamSubscription = [];
  }

  void listen(void Function(TransportClient event)? onData,
      {Function? onError, void Function()? onDone}) {
    dynamic res;
    if (useTLS) {
      res = secureServerSocket.listen((client) {
        var temp = TCPClient(config: {});
        temp.load(client);
        onData!(temp);
      }, onError: onError, onDone: onDone, cancelOnError: true);
    } else {
      res = serverSocket.listen((client) {
        var temp = TCPClient(config: {});
        temp.load(client);
        onData!(temp);
      }, onError: onError, onDone: onDone, cancelOnError: true);
    }
    streamSubscription.add(res);
  }

  int get port {
    return useTLS ? secureServerSocket.port : serverSocket.port;
  }

  InternetAddress get address {
    return useTLS ? secureServerSocket.address : serverSocket.address;
  }
} //}}}

class RRSServerSocket {
  //{{{
  dynamic serverSocket;
  List<dynamic> streamSubscription = [];

  RRSServerSocket({required this.serverSocket});

  Future<void> close() async {
    await serverSocket.close();
  }

  Future<void> clearListen() async {
    for (var i = 0, len = streamSubscription.length; i < len; ++i) {
      await streamSubscription[i].cancel();
    }
    streamSubscription = [];
  }

  void listen(void Function(RRSSocket event)? onData,
      {Function? onError, void Function()? onDone}) {
    var temp = serverSocket.listen((client) {
      onData!(RRSSocket(socket: client));
    }, onError: onError, onDone: onDone, cancelOnError: true);

    streamSubscription.add(temp);
  }
} //}}}

class TransportServer1 {
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

  TransportServer1({
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
    muxPassword = getValue(config, 'mux.maxIdle', '');
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
