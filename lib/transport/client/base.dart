import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:proxy/utils/utils.dart';

class TransportClient extends Stream<Uint8List> implements SecureSocket {
  //{{{
  late Socket socket;
  String status = 'init';
  String protocolName;
  String tag;
  Map<String, dynamic> config;

  // TLS
  late bool useTLS;
  late bool allowInsecure;
  late bool useSystemRoot;
  late Duration connectionTimeout;
  void Function(String line)? keyLog;
  List<String>? supportedProtocols;

  TransportClient(
      {required this.protocolName, required this.tag, required this.config}) {
    useTLS = getValue(config, 'tls.enabled', false);
    allowInsecure = getValue(config, 'tls.allowInsecure', false);
    useSystemRoot = getValue(config, 'tls.useSystemRoot', true);
    useSystemRoot = getValue(config, 'tls.useSystemRoot', true);
    connectionTimeout = getValue(config, 'tls.connectionTimeout', 100);
    supportedProtocols = getValue(config, 'tls.supportedProtocols', []);
  }

  Future<Socket> connect(host, int port) {
    if (useTLS) {
      var securityContext = SecurityContext(withTrustedRoots: useSystemRoot);
      return SecureSocket.connect(host, port,
              context: securityContext,
              onBadCertificate: onBadCertificate,
              keyLog: keyLog,
              supportedProtocols: supportedProtocols,
              timeout: connectionTimeout)
          .then(
        (value) {
          socket = value;
          status = 'created';
          return value;
        },
      );
    } else {
      return Socket.connect(host, port, timeout: connectionTimeout).then(
        (value) {
          socket = value;
          status = 'created';
          return value;
        },
      );
    }
  }

  bool onBadCertificate(X509Certificate certificate) {
    if (allowInsecure) {
      return true;
    }
    return false;
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

  @override
  Future close() {
    return socket.close().then(
      (value) {
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
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      socket.listen(onData, onError: onError, onDone: onDone);

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
