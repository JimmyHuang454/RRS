import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:proxy/outbounds/base.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/user.dart';
import 'package:proxy/utils/utils.dart';

class RRSSocket {
  //{{{
  dynamic socket;
  List<dynamic> streamSubscription = [];
  bool isClosed = false; //is remote channel closed?

  Traffic traffic = Traffic();

  RRSSocket({required this.socket});

  void clearListen() async {
    for (var i = 0, len = streamSubscription.length; i < len; ++i) {
      await streamSubscription[i].cancel();
    }
    streamSubscription = [];
  }

  void add(List<int> data) {
    if (isClosed) {
      return;
    }
    traffic.uplink += data.length;
    socket.add(data);
  }

  void close() {
    isClosed = true;
    socket.close();
  }

  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    runZonedGuarded(() {
      var temp = socket.listen((data) {
        onData!(data);
        traffic.downlink += (data as Uint8List).length;
      }, onDone: onDone, onError: onError, cancelOnError: true);

      streamSubscription.add(temp);
    }, (e, s) {
      isClosed = true;
      onError!(e);
    });
  }

  Future<dynamic> get done => socket.done;
} //}}}

class TransportClient {
  //{{{
  String tag = '';
  String protocolName;
  Map<String, dynamic> config;

  late Socket socket;
  List<dynamic> streamSubscription = [];

  // TLS
  late bool useTLS;
  late bool allowInsecure;
  late bool useSystemRoot;
  late List<String> supportedProtocols;

  late int connectionTimeout;
  late Duration timeout;
  late SecurityContext securityContext;
  late bool isMux;
  late int maxThread;
  late String muxPassword;

  TransportClient({required this.protocolName, required this.config}) {
    tag = getValue(config, 'tag', '');
    useTLS = getValue(config, 'tls.enabled', false);
    allowInsecure = getValue(config, 'tls.allowInsecure', false);
    useSystemRoot = getValue(config, 'tls.useSystemRoot', true);
    supportedProtocols =
        getValue(config, 'tls.supportedProtocols', ['http/1.1']);

    isMux = getValue(config, 'mux.enabled', false);
    maxThread = getValue(config, 'mux.maxThread', 8);
    if (isMux && (maxThread <= 0 || maxThread > 255)) {
      throw "maxThread should more than 0 and len than 255 .";
    }
    muxPassword = getValue(config, 'mux.password', '');

    connectionTimeout = getValue(config, 'connectionTimeout', 100);
    timeout = Duration(seconds: connectionTimeout);
  }

  Future<RRSSocket> connect(host, int port) async {
    if (useTLS) {
      socket = await SecureSocket.connect(host, port,
          context: securityContext,
          supportedProtocols: supportedProtocols,
          onBadCertificate: onBadCertificate,
          timeout: timeout);
    } else {
      socket = await Socket.connect(host, port, timeout: timeout);
    }
    return RRSSocket(socket: socket);
  }

  bool onBadCertificate(X509Certificate certificate) {
    return allowInsecure;
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
    rrsSocket.close();
    outboundStruct.traffic.uplink += rrsSocket.traffic.uplink;
    outboundStruct.traffic.downlink += rrsSocket.traffic.downlink;
  }
} //}}}

class RRSSocketBase extends RRSSocket {
  //{{{
  RRSSocket rrsSocket;

  RRSSocketBase({required this.rrsSocket}) : super(socket: rrsSocket.socket);

  @override
  bool get isClosed => rrsSocket.isClosed;

  @override
  dynamic get socket => rrsSocket.socket;

  @override
  List get streamSubscription => rrsSocket.streamSubscription;

  @override
  Traffic get traffic => rrsSocket.traffic;

  @override
  void clearListen() {
    rrsSocket.clearListen();
  }

  @override
  void add(List<int> data) {
    rrsSocket.add(data);
  }

  @override
  void close() {
    rrsSocket.close();
  }

  @override
  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    rrsSocket.listen(onData, onDone: onDone, onError: onError);
  }

  @override
  Future<dynamic> get done => rrsSocket.done;
} //}}}
