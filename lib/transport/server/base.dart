import 'dart:async';
import 'dart:io';
import 'package:proxy/transport/server/tcp.dart';
import 'package:proxy/utils/utils.dart';
import 'package:proxy/transport/client/base.dart';

abstract class RRSServerSocket {
  //{{{
  RRSServerSocket();

  Future<void> close();

  void listen(void Function(RRSSocket event)? onData,
      {Function(dynamic e, dynamic s)? onError, void Function()? onDone});
} //}}}

class RRSServerSocketBase extends RRSServerSocket {
  RRSServerSocket rrsServerSocket;

  RRSServerSocketBase({required this.rrsServerSocket});

  @override
  Future<void> close() async {
    await rrsServerSocket.close();
  }

  @override
  void listen(void Function(RRSSocket event)? onData,
      {Function(dynamic e, dynamic s)? onError, void Function()? onDone}) {
    runZonedGuarded(() {
      rrsServerSocket.listen((event) {
        onData!(event);
      }, onDone: onDone, onError: onError);
    }, (e, s) {
      if (onError != null) {
        onError(e, s);
      }
    });
  }
}

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
    ServerSocket serverSocket;
    if (useTLS) {
      serverSocket = (await SecureServerSocket.bind(
          address, port, securityContext,
          shared: false)) as ServerSocket;
    } else {
      serverSocket = await ServerSocket.bind(address, port, shared: false);
    }

    return RRSServerSocketBase(
        rrsServerSocket: TCPRRSServerSocket(serverSocket: serverSocket));
  }
} //}}}
