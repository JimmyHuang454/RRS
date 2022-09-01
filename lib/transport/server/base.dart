import 'dart:async';
import 'dart:io';
import 'package:proxy/utils/utils.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/client/tcp.dart';

abstract class TransportServer2 extends Stream<Socket> implements ServerSocket {
  //{{{
  String protocolName;
  late ServerSocket serverSocket;
  late SecureServerSocket secureServerSocket;
  late String tag;
  Map<String, dynamic> config;

  // TLS
  late bool useTLS;
  late bool requireClientCertificate;
  late List<String> supportedProtocols;

  TransportServer2({
    required this.protocolName,
    required this.config,
  }) {
    tag = config['tag'];
    useTLS = getValue(config, 'tls.enabled', false);
    requireClientCertificate =
        getValue(config, 'tls.requireClientCertificate', true);
    supportedProtocols = getValue(config, 'tls.supportedProtocols', ['']);
  }

  Future<ServerSocket> bind(address, int port) {
    if (useTLS) {
      var securityContext = SecurityContext(withTrustedRoots: useTLS);
      return SecureServerSocket.bind(address, port, securityContext,
              requireClientCertificate: requireClientCertificate,
              supportedProtocols: supportedProtocols,
              shared: false)
          .then((value) {
        secureServerSocket = value;
        return this;
      });
    }
    return ServerSocket.bind(address, port, shared: false).then((value) {
      serverSocket = value;
      return serverSocket;
    });
  }

  @override
  InternetAddress get address {
    return useTLS ? secureServerSocket.address : serverSocket.address;
  }

  @override
  Future<ServerSocket> close() {
    if (useTLS) {
      return secureServerSocket.close().then(
        (value) {
          return this;
        },
      );
    }
    return serverSocket.close();
  }

  @override
  StreamSubscription<Socket> listen(void Function(Socket event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    if (useTLS) {
      return secureServerSocket.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
    }
    return serverSocket.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  int get port {
    return useTLS ? secureServerSocket.port : serverSocket.port;
  }
} //}}}

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
