import 'dart:typed_data';

import 'package:cryptography/helpers.dart';

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
  List<int> data = [];
  List<int> type = [];
  List<int> len = [];

  Extension({required List<int> rawData}) {
    type = rawData.sublist(0, 2);
    len = rawData.sublist(2, 4);
    data = rawData.sublist(4);
  }

  List<int> build() {
    return type + len + data;
  }
}

class ClientHello extends Handshake {
  List<Extension> extensionList;

  ClientHello(
      {required super.random,
      super.sessionID,
      this.extensionList = const [],
      required super.tlsVersion})
      : super(handshakeType: HandshakeType.clientHello);

  void buildExtension() {
    List<int> extensions = [];
    for (var i = 0, len = extensionList.length; i < len; ++i) {
      extensions += extensionList[i].build();
    }

    var extensionLength = Uint8List(2)
      ..buffer.asByteData().setInt16(0, extensions.length, Endian.big);

    data += extensionLength + extensions;
  }

  @override
  List<int> build() {
    var playloadLen = Uint8List(3)
      ..buffer.asByteData().setInt32(0, data.length, Endian.big);

    data = [handshakeType.value] + playloadLen + tlsVersion.value;
    return super.build();
  }
}
