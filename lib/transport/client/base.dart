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

  Future<void> add(List<int> data);

  Future<void> close();
  Future<void> clearListen();

  void listen(Future<void> Function(Uint8List event)? onData,
      {Future<void> Function(dynamic e, dynamic s)? onError,
      Future<void> Function()? onDone});
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
  SecurityContext? securityContext;

  TransportClient({required this.protocolName, required this.config}) {
    tag = getValue(config, 'tag', '');
    useTLS = getValue(config, 'tls.enabled', false);
    allowInsecure = getValue(config, 'tls.allowInsecure', false);
    useSystemRoot = getValue(config, 'tls.useSystemRoot', true);
    var temp = getValue(config, 'tls.supportedProtocols', '');
    if (temp != '') {
      supportedProtocols = temp;
    }

    var connectionTimeout = getValue(config, 'connectionTimeout', 5);
    timeout = Duration(seconds: connectionTimeout);
  }

  Future<RRSSocket> connect(host, int port,
      {dynamic sourceAddress, String sni = ""}) async {
    var socket = await Socket.connect(host, port,
        timeout: timeout, sourceAddress: sourceAddress);

    if (sni == "") {
      sni = host;
    }

    if (useTLS!) {
      socket = await SecureSocket.secure(socket,
          host: sni,
          context: securityContext,
          supportedProtocols: supportedProtocols,
          onBadCertificate: onBadCertificate);
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
      required this.outboundStruct}) {
    link.outAddress = outboundStruct.outAddress!;
    link.outPort = outboundStruct.outPort!;
  }

  @override
  Future<void> close() async {
    outboundStruct.traffic.uplink += super.traffic.uplink;
    outboundStruct.traffic.downlink += super.traffic.downlink;
    await super.close();
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
  Future<void> add(List<int> data) async {
    if (isClosed) {
      return;
    }
    traffic.uplink += data.length;
    await rrsSocket.add(data);
  }

  @override
  Future<void> clearListen() async {
    await rrsSocket.clearListen();
  }

  @override
  Future<void> close() async {
    if (isClosed) {
      return;
    }
    isClosed = true;
    await rrsSocket.close();
  }

  @override
  void listen(Future<void> Function(Uint8List event)? onData,
      {Future<void> Function(dynamic e, dynamic s)? onError,
      Future<void> Function()? onDone}) {
    runZonedGuarded(() {
      rrsSocket.listen((data) async {
        traffic.downlink += data.length;
        await onData!(data);
      }, onDone: () async {
        isClosed = true;
        if (onDone != null) {
          await onDone();
        }
      }, onError: (e, s) async {
        isClosed = true;
        if (onError != null) {
          await onError(e, s);
        }
      });
    }, (e, s) async {
      logger.info('listen error: $e $s');
      if (onError != null) {
        await onError(e, s);
      }
    });
  }

  @override
  Future<dynamic>? get done => rrsSocket.done;
} //}}}
