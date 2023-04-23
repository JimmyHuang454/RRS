import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:proxy/outbounds/base.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/user.dart';
import 'package:proxy/utils/utils.dart';

abstract class RRSSocket {
  //{{{
  bool isClosed = false;
  Traffic traffic = Traffic();
  Future<dynamic>? done;

  RRSSocket();

  void add(List<int> data);

  void close();

  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone});
} //}}}

class TransportClient {
  //{{{
  String tag = '';
  String protocolName;
  Map<String, dynamic> config;

  List<dynamic> streamSubscription = [];

  // TLS
  bool? useTLS;
  bool? allowInsecure;
  bool? useSystemRoot;
  List<String>? supportedProtocols;

  Duration? timeout;
  late SecurityContext securityContext;
  late bool isMux;
  late int maxThread;
  late String muxPassword;

  TransportClient({required this.protocolName, required this.config}) {
    tag = getValue(config, 'tag', '');
    useTLS = getValue(config, 'tls.enabled', false);
    allowInsecure = getValue(config, 'tls.allowInsecure', false);
    useSystemRoot = getValue(config, 'tls.useSystemRoot', true);
    var temp = getValue(config, 'tls.supportedProtocols', ['']);
    if (temp != ['']) {
      supportedProtocols = temp;
    }

    isMux = getValue(config, 'mux.enabled', false);
    maxThread = getValue(config, 'mux.maxThread', 8);
    if (isMux && (maxThread <= 0 || maxThread > 255)) {
      throw "maxThread should more than 0 and len than 255 .";
    }
    muxPassword = getValue(config, 'mux.password', '');

    var connectionTimeout = getValue(config, 'connectionTimeout', 100);
    timeout = Duration(seconds: connectionTimeout);
  }

  Future<RRSSocket> connect(host, int port) async {
    Socket socket;
    if (useTLS!) {
      socket = await SecureSocket.connect(host, port,
          context: securityContext,
          supportedProtocols: supportedProtocols,
          onBadCertificate: onBadCertificate,
          timeout: timeout!);
    } else {
      socket = await Socket.connect(host, port, timeout: timeout);
    }
    return RRSSocketBase(rrsSocket: TCPRRSSocket(socket: socket));
  }

  bool onBadCertificate(X509Certificate certificate) {
    return allowInsecure!;
  }
} //}}}

class Connect extends RRSSocketBase {
  //{{{
  OutboundStruct outboundStruct;
  Link link;

  Connect(
      {required super.rrsSocket,
      required this.link,
      required this.outboundStruct});

  @override
  void close() {
    super.close();
    outboundStruct.traffic.uplink += super.traffic.uplink;
    outboundStruct.traffic.downlink += super.traffic.downlink;
  }
} //}}}

class RRSSocketBase extends RRSSocket {
  //{{{
  RRSSocket rrsSocket;

  RRSSocketBase({required this.rrsSocket});

  @override
  bool get isClosed => rrsSocket.isClosed;

  @override
  Traffic get traffic => rrsSocket.traffic;

  @override
  void add(List<int> data) {
    if (isClosed) {
      return;
    }
    traffic.uplink += data.length;
    rrsSocket.add(data);
  }

  @override
  void close() {
    if (isClosed) {
      return;
    }
    isClosed = true;
    rrsSocket.close();
  }

  @override
  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    rrsSocket.listen((data) {
      traffic.downlink += data.length;
      onData!(data);
    }, onDone: () {
      isClosed = true;
      onDone!();
    }, onError: (e, s) {
      isClosed = true;
      onError!(e, s);
    });
    // runZonedGuarded(() {
    // }, (e, s) {
    //   if (onError != null) {
    //     onError(e);
    //     devPrint(e);
    //     devPrint(s);
    //   }
    // });
  }

  @override
  Future<dynamic>? get done => rrsSocket.done;
} //}}}
