import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:proxy/utils/utils.dart';

class TransportClient2 extends Stream<Uint8List> implements SecureSocket {
  //{{{
  late Socket socket;
  String status = 'init';
  String protocolName;
  late String tag;
  Map<String, dynamic> config;
  List<dynamic> streamListen = [];

  // TLS
  late bool useTLS;
  late bool allowInsecure;
  late bool useSystemRoot;
  late int connectionTimeout;
  late List<String> supportedProtocols;

  TransportClient2({required this.protocolName, required this.config}) {
    tag = config['tag'];
    useTLS = getValue(config, 'tls.enabled', false);
    allowInsecure = getValue(config, 'tls.allowInsecure', false);
    useSystemRoot = getValue(config, 'tls.useSystemRoot', true);
    supportedProtocols =
        getValue(config, 'tls.supportedProtocols', ['http/1.1']);
    connectionTimeout = getValue(config, 'connectionTimeout', 100);
  }

  Future<Socket> connect(host, int port) {
    var tempDuration = Duration(seconds: connectionTimeout);
    if (useTLS) {
      var securityContext = SecurityContext(withTrustedRoots: useSystemRoot);
      return SecureSocket.connect(host, port,
              context: securityContext,
              supportedProtocols: supportedProtocols,
              onBadCertificate: onBadCertificate,
              timeout: tempDuration)
          .then(
        (value) {
          socket = value;
          status = 'created';
          return value;
        },
      );
    } else {
      return Socket.connect(host, port, timeout: tempDuration).then(
        (value) {
          socket = value;
          status = 'created';
          return value;
        },
      );
    }
  }

  bool onBadCertificate(X509Certificate certificate) {
    return allowInsecure;
  }

  @override
  Encoding get encoding => socket.encoding;

  @override
  void add(List<int> data) {
    socket.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      socket.addError(error, stackTrace);

  @override
  Future addStream(Stream<List<int>> stream) => socket.addStream(stream);

  @override
  InternetAddress get address => socket.address;

  void clearListen() {
    for (var i = 0, len = streamListen.length; i < len; ++i) {
      streamListen[i].cancel();
    }
  }

  @override
  Future close() {
    return socket.close().then(
      (value) {
        clearListen();
        status = 'closed';
        return value;
      },
    );
  }

  @override
  void destroy() {
    if (status == 'created') {
      socket.destroy();
    }
    status = 'closed';
  }

  @override
  Future get done => socket.done;

  @override
  Future flush() => socket.flush();

  @override
  Uint8List getRawOption(RawSocketOption option) => socket.getRawOption(option);

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData,
      {Function? onError,
      void Function()? onDone,
      bool? cancelOnError = true}) {
    var temp = socket.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
    streamListen.add(temp);
    return temp;
  }

  @override
  int get port => socket.port;

  @override
  InternetAddress get remoteAddress => socket.remoteAddress;

  @override
  int get remotePort => socket.remotePort;

  @override
  bool setOption(SocketOption option, bool enabled) =>
      socket.setOption(option, enabled);

  @override
  void setRawOption(RawSocketOption option) => socket.setRawOption(option);

  @override
  void write(Object? object) => socket.write(object);

  @override
  void writeAll(Iterable objects, [String separator = ""]) =>
      socket.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => socket.writeCharCode(charCode);

  @override
  void writeln([Object? object = ""]) => socket.writeln(object);

  @override
  set encoding(Encoding value) {
    socket.encoding = value;
  }

  @override
  // TODO: implement peerCertificate
  X509Certificate? get peerCertificate => throw UnimplementedError();

  @override
  void renegotiate(
      {bool useSessionCache = true,
      bool requestClientCertificate = false,
      bool requireClientCertificate = false}) {
    // TODO: implement renegotiate
  }

  @override
  // TODO: implement selectedProtocol
  String? get selectedProtocol => throw UnimplementedError();
} //}}}

class TransportClient {
  //{{{
  String status = 'init';
  String protocolName;
  late String tag;
  Map<String, dynamic> config;

  late Socket socket;
  List<dynamic> streamSubscription = [];
  // void Function(Uint8List event)? onData;
  // Function? onError;
  // void Function()? onDone;

  // TLS
  late bool useTLS;
  late bool allowInsecure;
  late bool useSystemRoot;
  late int connectionTimeout;
  late List<String> supportedProtocols;

  bool compress = false;

  TransportClient({required this.protocolName, required this.config}) {
    tag = config['tag'];
    useTLS = getValue(config, 'tls.enabled', false);
    allowInsecure = getValue(config, 'tls.allowInsecure', false);
    useSystemRoot = getValue(config, 'tls.useSystemRoot', true);
    supportedProtocols =
        getValue(config, 'tls.supportedProtocols', ['http/1.1']);
    connectionTimeout = getValue(config, 'connectionTimeout', 100);
    compress = getValue(config, 'compress.enabled', false);
  }

  Future<void> connect(host, int port) async {
    var tempDuration = Duration(seconds: connectionTimeout);
    if (useTLS) {
      var securityContext = SecurityContext(withTrustedRoots: useSystemRoot);
      await SecureSocket.connect(host, port,
              context: securityContext,
              supportedProtocols: supportedProtocols,
              onBadCertificate: onBadCertificate,
              timeout: tempDuration)
          .then(
        (value) {
          socket = value;
          status = 'created';
          return value;
        },
      );
    } else {
      await Socket.connect(host, port, timeout: tempDuration).then(
        (value) {
          socket = value;
          status = 'created';
          return value;
        },
      );
    }
  }

  bool onBadCertificate(X509Certificate certificate) {
    return allowInsecure;
  }

  void clearListen() {
    for (var i = 0, len = streamSubscription.length; i < len; ++i) {
      streamSubscription[i].cancel();
    }
  }

  void add(List<int> data) {
    socket.add(data);
  }

  Future close() {
    return socket.close().then(
      (value) {
        clearListen();
        status = 'closed';
        return value;
      },
    );
  }

  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    var temp = socket.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: true);

    streamSubscription.add(temp);
  }

  Future get done => socket.done;
  InternetAddress get remoteAddress => socket.remoteAddress;
  int get remotePort => socket.remotePort;
} //}}}
