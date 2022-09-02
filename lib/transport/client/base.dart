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
  bool isClosed = false;

  Traffic traffic = Traffic();

  RRSSocket({required this.socket});

  Future<void> clearListen() async {
    for (var i = 0, len = streamSubscription.length; i < len; ++i) {
      await streamSubscription[i].cancel();
    }
    streamSubscription = [];
  }

  void add(List<int> data) {
    socket.add(data);
    traffic.uplink += data.length;
  }

  Future close() async {
    await socket.close();
    await clearListen();
    isClosed = true;
  }

  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    var temp = socket.listen((data) {
      onData!(data);
      traffic.downlink += (data as Uint8List).length;
    }, onError: onError, onDone: onDone, cancelOnError: true);

    try {
      socket.done.then((value) {
        if (onDone != null) {
          onDone();
        }
      }, onError: (e) {
        if (onError != null) {
          onError(e);
        }
      });
    } catch (_) {}

    streamSubscription.add(temp);
  }
} //}}}

class TransportClient1 {
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

  TransportClient1({required this.protocolName, required this.config}) {
    tag = getValue(config, 'tag', '');
    useTLS = getValue(config, 'tls.enabled', false);
    allowInsecure = getValue(config, 'tls.allowInsecure', false);
    useSystemRoot = getValue(config, 'tls.useSystemRoot', true);
    supportedProtocols =
        getValue(config, 'tls.supportedProtocols', ['http/1.1']);

    isMux = getValue(config, 'mux.enabled', false);
    maxThread = getValue(config, 'mux.maxThread', 8);

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

class TransportClient {
  //{{{
  String status = 'init';
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

  TransportClient({required this.protocolName, required this.config}) {
    tag = getValue(config, 'tag', '');
    useTLS = getValue(config, 'tls.enabled', false);
    allowInsecure = getValue(config, 'tls.allowInsecure', false);
    useSystemRoot = getValue(config, 'tls.useSystemRoot', true);
    supportedProtocols =
        getValue(config, 'tls.supportedProtocols', ['http/1.1']);
    connectionTimeout = getValue(config, 'connectionTimeout', 100);
    timeout = Duration(seconds: connectionTimeout);
  }

  void load(s) {
    socket = s;
  }

  Future<void> connect(host, int port) async {
    if (useTLS) {
      socket = await SecureSocket.connect(host, port,
          context: securityContext,
          supportedProtocols: supportedProtocols,
          onBadCertificate: onBadCertificate,
          timeout: timeout);
    } else {
      socket = await Socket.connect(host, port, timeout: timeout);
    }
    status = 'created';
  }

  bool onBadCertificate(X509Certificate certificate) {
    return allowInsecure;
  }

  Future<void> clearListen() async {
    for (var i = 0, len = streamSubscription.length; i < len; ++i) {
      await streamSubscription[i].cancel();
    }
    streamSubscription = [];
  }

  void add(List<int> data) {
    socket.add(data);
  }

  Future close() async {
    status = 'closed';
    await socket.close();
    await clearListen();
  }

  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    var temp = socket.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: true);

    socket.done.then((value) {
      if (onDone != null) {
        onDone();
      }
    }, onError: (e) {
      if (onError != null) {
        onError(e);
      }
    });

    streamSubscription.add(temp);
  }
} //}}}

class Connect extends TransportClient {
  //{{{
  TransportClient transportClient;
  OutboundStruct outboundStruct;
  Link link;
  late RawDatagramSocket udpClient;

  Connect(
      {required this.transportClient,
      required this.link,
      required this.outboundStruct})
      : super(protocolName: 'connecting', config: {});

  @override
  Future<void> connect(host, int port) async {
    if (link.streamType == 'TCP') {
      await transportClient.connect(host, port);
    } else {
      udpClient = await RawDatagramSocket.bind(host, port);
    }
  }

  @override
  void add(List<int> data) {
    if (link.streamType == 'TCP') {
      transportClient.add(data);
    } else {
      udpClient.send(
          data, InternetAddress(link.targetAddress.address), link.targetport);
    }
    outboundStruct.traffic.uplink += data.length;
    link.traffic.uplink += data.length;
  }

  @override
  Future close() async {
    if (link.streamType == 'TCP') {
      await transportClient.close();
    } else {
      udpClient.close();
    }
  }

  @override
  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    if (link.streamType == 'TCP') {
      transportClient.listen((data) {
        link.traffic.downlink += data.length;
        outboundStruct.traffic.downlink += data.length;
        onData!(data);
      }, onDone: onDone, onError: onError);
    } else {
      var temp = udpClient.listen((event) {
        Datagram? d = udpClient.receive();
        if (d == null) {
          return;
        }
        var data = d.data;
        link.traffic.downlink += data.length;
        outboundStruct.traffic.downlink += data.length;
        onData!(data);
      }, onError: onError, onDone: onDone, cancelOnError: true);
      streamSubscription.add(temp);
    }
  }
} //}}}
