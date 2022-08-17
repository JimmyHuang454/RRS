import 'dart:async';
import 'dart:io';
import 'package:proxy/utils/utils.dart';

class TransportServer extends Stream<Socket> implements ServerSocket {
  String protocolName;
  late ServerSocket serverSocket;
  late SecureServerSocket secureServerSocket;
  late String tag;
  Map<String, dynamic> config;

  // TLS
  late bool useTLS;
  late int backlog;
  late bool v6Only;
  late bool requestClientCertificate;
  late bool requireClientCertificate;
  late List<String>? supportedProtocols;
  late bool shared;

  TransportServer({
    required this.protocolName,
    required this.config,
  }) {
    tag = config['tag'];
    useTLS = getValue(config, 'tls.enabled', false);
    requestClientCertificate =
        getValue(config, 'tls.requireClientCertificate', true);
    supportedProtocols = getValue(config, 'tls.supportedProtocols', []);
  }

  Future<ServerSocket> bind(address, int port) {
    if (useTLS) {
      var securityContext = SecurityContext(withTrustedRoots: useTLS);
      return SecureServerSocket.bind(address, port, securityContext,
              backlog: backlog,
              v6Only: v6Only,
              requestClientCertificate: requestClientCertificate,
              requireClientCertificate: requireClientCertificate,
              supportedProtocols: supportedProtocols,
              shared: shared)
          .then((value) {
        secureServerSocket = value;
        return this;
      });
    }
    return ServerSocket.bind(address, port, shared: shared).then((value) {
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
}
