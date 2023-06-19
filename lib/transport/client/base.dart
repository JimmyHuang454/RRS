import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:proxy/obj_list.dart';
import 'package:proxy/outbounds/base.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/transport/jls/client.dart';
import 'package:proxy/transport/jls/jls.dart';
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
  bool? useJLS;
  bool? allowInsecure;
  bool? useSystemRoot;
  List<String>? supportedProtocols;
  String outSNI = "";

  Duration? timeout;
  SecurityContext? securityContext;

  TransportClient({required this.protocolName, required this.config}) {
    tag = getValue(config, 'tag', '');
    useTLS = getValue(config, 'tls.enabled', false);
    outSNI = getValue(config, 'tls.sni', '');
    allowInsecure = getValue(config, 'tls.allowInsecure', false);
    useSystemRoot = getValue(config, 'tls.useSystemRoot', true);
    var temp = getValue(config, 'tls.supportedProtocols', '');
    if (temp != '') {
      supportedProtocols = temp;
    }

    var connectionTimeout = getValue(config, 'connectionTimeout', 5);
    timeout = Duration(seconds: connectionTimeout);

    useJLS = getValue(config, 'jls.enabled', false);
  }

  JLSHandShakeClient buildJLSClient() {
    var temp = getValue(config, 'jls.fingerPrint', 'default');
    var fingerPrint = jlsFringerPrintList[temp]!;

    var pwd = getValue(config, 'jls.password', '');
    var iv = getValue(config, 'jls.random', '');
    if (pwd == '' || iv == '') {
      throw Exception('missing password and iv in JLS');
    }
    var jlsHandShakeClient = JLSHandShakeClient(
        pwdStr: pwd, ivStr: iv, local: fingerPrint.buildClientHello());

    var fallbackWebsite = getValue(config, 'jls.fallback', '');
    if (fallbackWebsite != '') {
      jlsHandShakeClient.setServerName(utf8.encode(fallbackWebsite));
    }
    return jlsHandShakeClient;
  }

  Future<RRSSocket> connect(host, int port, {dynamic sourceAddress}) async {
    var socket = await Socket.connect(host, port,
        timeout: timeout, sourceAddress: sourceAddress);

    if (outSNI == "") {
      outSNI = host;
    }

    if (useTLS! && !(useJLS!)) {
      socket = await SecureSocket.secure(socket,
          host: outSNI,
          context: securityContext,
          supportedProtocols: supportedProtocols,
          onBadCertificate: onBadCertificate);
    }

    var res = RRSSocketBase(rrsSocket: TCPRRSSocket(socket: socket));

    if (useJLS! && !(useTLS!)) {
      var jls = JLSSocket(rrsSocket: res, jlsHandShakeSide: buildJLSClient());
      await jls.secure(timeout!);
      return jls;
    }
    return res;
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
