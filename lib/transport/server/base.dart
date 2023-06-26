import 'dart:async';
import 'dart:io';
import 'package:proxy/obj_list.dart';
import 'package:proxy/transport/jls/format.dart';
import 'package:proxy/transport/jls/jls.dart';
import 'package:proxy/transport/jls/server.dart';
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

  Duration? jlsTimeout;

  late bool useTLS;
  late bool useJLS;
  late bool requireClientCertificate;
  late List<String> supportedProtocols;
  late SecurityContext securityContext;

  String? fallbackWebsite;
  FingerPrint? fingerPrint;
  String? pwd, iv;

  TransportServer({
    required this.protocolName,
    required this.config,
  }) {
    tag = getValue(config, 'tag', '');
    useTLS = getValue(config, 'tls.enable', false);
    useJLS = getValue(config, 'jls.enable', false);
    requireClientCertificate =
        getValue(config, 'tls.requireClientCertificate', true);
    supportedProtocols = getValue(config, 'tls.supportedProtocols', ['']);
    // securityContext = SecurityContext(withTrustedRoots: useTLS);

    useJLS = getValue(config, 'jls.enable', false);
    if (useJLS) {
      fallbackWebsite = getValue(config, 'jls.fallback', 'www.visa.cn');
      var temp = getValue(config, 'jls.fingerPrint', 'default');
      fingerPrint = jlsFringerPrintList[temp]!;

      var timeout = getValue(config, 'jls.timeout', 10);
      jlsTimeout = Duration(seconds: timeout);

      pwd = getValue(config, 'jls.password', '');
      iv = getValue(config, 'jls.random', '');
      if (pwd == '' || iv == '') {
        throw Exception('missing password and iv in JLS');
      }
    }
  }

  JLSServerHandler buildJLSServer(RRSSocket client) {
    var res = JLSServer(pwdStr: pwd!, ivStr: iv!, fingerPrint: fingerPrint!);
    return JLSServerHandler(
        client: client, jls: res, fallbackWebsite: fallbackWebsite!);
  }

  Future<RRSServerSocket> bind(address, int port) async {
    ServerSocket serverSocket;

    if (useTLS && !useJLS) {
      serverSocket = (await SecureServerSocket.bind(
          address, port, securityContext,
          shared: false)) as ServerSocket;
    } else {
      serverSocket = await ServerSocket.bind(address, port, shared: false);
    }

    var s = TCPRRSServerSocket(serverSocket: serverSocket);

    if (useJLS) {
      if (useTLS) {
        throw Exception('can only use JLS or TLS');
      }
      return JLSServerSocket(rrsServerSocket: s, newJLSServer: buildJLSServer);
    }

    return RRSServerSocketBase(rrsServerSocket: s);
  }
} //}}}
