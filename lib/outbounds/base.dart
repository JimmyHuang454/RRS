import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:proxy/utils/utils.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/obj_list.dart';

abstract class OutboundStruct extends Stream<Uint8List>
    implements SecureSocket {
  String protocolName;
  String protocolVersion;
  late String outAddress;
  late int outPort;
  late String tag;
  late String outStream;
  late TransportClient socket;

  Map<String, dynamic> config;

  bool useFakeDNS = false;

  OutboundStruct(
      {required this.protocolName,
      required this.protocolVersion,
      required this.config}) {
    tag = config['tag'];
    outStream = config['outStream'];
    socket = getClient()();
    outAddress = getValue(config, 'setting.address', '');
    outPort = getValue(config, 'setting.port', 0);
  }

  TransportClient Function() getClient() {
    if (!outStreamList.containsKey(outStream)) {
      throw "wrong outStream tag.";
    }
    return outStreamList[outStream]!;
  }

  Future<Socket> connect2(Link link);

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
    return socket.close();
  }

  @override
  void destroy() {
    socket.destroy();
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
}
