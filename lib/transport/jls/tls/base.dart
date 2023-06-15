import 'dart:typed_data';

import 'package:cryptography/helpers.dart';
import 'package:proxy/utils/utils.dart';

enum ContentType {
  handshake(0x16),
  changeCipherSpec(0x14),
  applicationData(0x17);

  const ContentType(this.value);
  final int value;
}

enum TLSVersion {
  tls1_0([0x03, 0x01]),
  tls1_1([0x03, 0x02]),
  tls1_2([0x03, 0x03]),
  tls1_3([0x03, 0x04]);

  const TLSVersion(this.value);
  final List<int> value;
}

enum ExtensionType {
  serverName([0, 0]),
  supportedVersion([0, 0x2b]);

  const ExtensionType(this.value);
  final List<int> value;
}

enum HandshakeType {
  clientHello(1),
  serverHello(2);

  const HandshakeType(this.value);
  final int value;
}

void checkLen(List<dynamic> input, int len) {
  if (input.length != len) {
    throw Exception('wrong len');
  }
}

class TLSBase {
  TLSVersion tlsVersion;
  ContentType contentType;
  List<int> data = [];

  TLSBase({required this.tlsVersion, required this.contentType});

  List<int> build() {
    var len = Uint8List(2)
      ..buffer.asByteData().setInt16(0, data.length, Endian.big);
    return [contentType.value] + tlsVersion.value + len + data;
  }
}

class ChangeSpec extends TLSBase {
  ChangeSpec({required super.tlsVersion})
      : super(contentType: ContentType.changeCipherSpec);
  @override
  List<int> build() {
    data = [1];
    return super.build();
  }
}

class Handshake extends TLSBase {
  HandshakeType handshakeType;
  List<int> random;
  List<int>? sessionID;

  Handshake(
      {required this.handshakeType,
      required this.random,
      this.sessionID,
      required super.tlsVersion})
      : super(contentType: ContentType.handshake) {
    sessionID ??= randomBytes(32);
    checkLen(random, 32);
  }

  @override
  List<int> build() {
    data = tlsVersion.value + random + [sessionID!.length] + sessionID! + data;

    var len = Uint8List(4)
      ..buffer.asByteData().setInt32(0, data.length, Endian.big);

    data = [handshakeType.value] + len.sublist(1) + data;
    return super.build();
  }
}

class Extension {
  List<int> type = [];
  List<int> data = [];

  Extension({required this.type, required this.data}) {
    checkLen(type, 2);
  }

  List<int> build() {
    var len = Uint8List(2)
      ..buffer.asByteData().setInt16(0, data.length, Endian.big);
    return type + len + data;
  }
}

class ExtensionList {
  List<Extension> list = [];

  ExtensionList({required this.list});

  ExtensionList.parse({required List<int> rawData}) {
    ByteData byteData =
        ByteData.sublistView(Uint8List.fromList(rawData.sublist(0, 2)));
    var len = byteData.getUint16(0, Endian.big);
    rawData = rawData.sublist(2);

    var len2 = 0;
    while (len2 < len) {
      var type = rawData.sublist(0, 2);
      rawData = rawData.sublist(2);

      byteData =
          ByteData.sublistView(Uint8List.fromList(rawData.sublist(0, 2)));
      var extensionsLen = byteData.getUint16(0, Endian.big);
      rawData = rawData.sublist(2);
      list.add(Extension(type: type, data: rawData.sublist(0, extensionsLen)));
      rawData = rawData.sublist(extensionsLen);
      len2 += extensionsLen + 4;
    }
  }

  List<int> build() {
    List<int> extensions = [];
    for (var i = 0; i < list.length; i++) {
      extensions += list[i].build();
    }
    var len = Uint8List(2)
      ..buffer.asByteData().setInt16(0, extensions.length, Endian.big);
    return len + extensions;
  }
}

class ClientCipherSuites {
  List<int> data = [];

  ClientCipherSuites({required this.data}) {
    checkLen(data, 2);
  }

  List<int> build() {
    var len = Uint8List(2)
      ..buffer.asByteData().setInt16(0, data.length, Endian.big);
    return len + data;
  }
}

class ClientCompressionMethod {
  List<int> data = [];

  ClientCompressionMethod({required this.data});

  List<int> build() {
    var len = Uint8List(1)..buffer.asByteData().setInt8(0, data.length);
    return len + data;
  }
}

class ClientHello extends Handshake {
  ExtensionList extensionList;
  ClientCipherSuites clientCipherSuites;
  ClientCompressionMethod clientCompressionMethod;

  ClientHello(
      {required super.random,
      super.sessionID,
      required this.clientCipherSuites,
      required this.clientCompressionMethod,
      required this.extensionList,
      required super.tlsVersion})
      : super(handshakeType: HandshakeType.clientHello);

  @override
  List<int> build() {
    data = clientCipherSuites.build() +
        clientCompressionMethod.build() +
        extensionList.build();
    return super.build();
  }
}

class ServerHello extends Handshake {
  ExtensionList extensionList;
  int serverCompressionMethod;
  int serverCipherSuite;

  ServerHello(
      {required super.random,
      super.sessionID,
      required this.serverCompressionMethod,
      required this.serverCipherSuite,
      required this.extensionList,
      required super.tlsVersion})
      : super(handshakeType: HandshakeType.serverHello);

  @override
  List<int> build() {
    data =
        [serverCipherSuite] + [serverCompressionMethod] + extensionList.build();
    return super.build();
  }
}
