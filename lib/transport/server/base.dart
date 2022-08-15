import 'dart:async';
import 'dart:io';

TransportServer newTransportServer() => TransportServer();

class TransportServer extends Stream<SecureSocket>
    implements SecureServerSocket {
  late SecureServerSocket secureServerSocket;

  // TLS
  SecurityContext? context;
  int backlog;
  bool v6Only;
  bool requestClientCertificate;
  bool requireClientCertificate;
  List<String>? supportedProtocols;
  bool shared;

  TransportServer(
      {this.context,
      this.backlog = 0,
      this.v6Only = false,
      this.requestClientCertificate = false,
      this.requireClientCertificate = false,
      this.supportedProtocols,
      this.shared = false});

  Future<SecureServerSocket> bind(address, int port) {
    return SecureServerSocket.bind(address, port, context,
            backlog: backlog,
            v6Only: v6Only,
            requestClientCertificate: requestClientCertificate,
            requireClientCertificate: requireClientCertificate,
            supportedProtocols: supportedProtocols,
            shared: shared)
        .then((serverSocket) {
      secureServerSocket = serverSocket;
      return serverSocket;
    });
  }

  @override
  InternetAddress get address => secureServerSocket.address;

  @override
  Future<SecureServerSocket> close() {
    return secureServerSocket.close();
  }

  @override
  StreamSubscription<SecureSocket> listen(
      void Function(SecureSocket event)? onData,
      {Function? onError,
      void Function()? onDone,
      bool? cancelOnError}) {
    return secureServerSocket.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  int get port => secureServerSocket.port;
}
