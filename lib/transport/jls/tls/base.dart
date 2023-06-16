import 'dart:typed_data';

import 'package:proxy/utils/utils.dart';
import 'package:quiver/collection.dart';

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

enum HandshakeType {
  clientHello(1),
  serverHello(2);

  const HandshakeType(this.value);
  final int value;
}

enum ExtensionType {
  serverName([0, 0]);

  const ExtensionType(this.value);
  final List<int> value;
}

void checkLen(List<dynamic> input, int len) {
  if (input.length != len) {
    throw Exception('wrong len');
  }
}

class TLSBase {
  TLSVersion? tlsVersion;
  ContentType? contentType;
  List<int> data = [];

  TLSBase({required this.tlsVersion, required this.contentType});

  TLSBase.parse({required List<int> rawData}) {
    var type = rawData[0];
    var version = rawData.sublist(1, 3);

    if (listsEqual(version, TLSVersion.tls1_0.value)) {
      tlsVersion = TLSVersion.tls1_0;
    } else if (listsEqual(version, TLSVersion.tls1_1.value)) {
      tlsVersion = TLSVersion.tls1_1;
    } else if (listsEqual(version, TLSVersion.tls1_2.value)) {
      tlsVersion = TLSVersion.tls1_2;
    } else if (listsEqual(version, TLSVersion.tls1_3.value)) {
      tlsVersion = TLSVersion.tls1_3;
    } else {
      throw Exception('unknow tls version. $version');
    }

    if (type == ContentType.handshake.value) {
      contentType = ContentType.handshake;
    } else if (type == ContentType.changeCipherSpec.value) {
      contentType = ContentType.changeCipherSpec;
    } else if (type == ContentType.applicationData.value) {
      contentType = ContentType.applicationData;
    }
  }

  List<int> build() {
    var len = Uint8List(2)
      ..buffer.asByteData().setInt16(0, data.length, Endian.big);
    return [contentType!.value] + tlsVersion!.value + len + data;
  }
}

class ChangeSpec extends TLSBase {
  ChangeSpec({super.tlsVersion = TLSVersion.tls1_2})
      : super(contentType: ContentType.changeCipherSpec);
  @override
  List<int> build() {
    data = [1];
    return super.build();
  }
}

class ApplicationData extends TLSBase {
  ApplicationData.parse({required List<int> rawData})
      : super.parse(rawData: rawData) {
    data = rawData.sublist(5);
  }
}

class Handshake extends TLSBase {
  HandshakeType? handshakeType;
  List<int>? random = [];
  List<int>? sessionID = [];
  List<int>? len = [];
  TLSVersion? handshakeTLSVersion;

  Handshake(
      {this.handshakeType = HandshakeType.clientHello,
      this.random = const [],
      this.handshakeTLSVersion = TLSVersion.tls1_2,
      this.sessionID = const [],
      super.tlsVersion = TLSVersion.tls1_2})
      : super(contentType: ContentType.handshake);

  Handshake.parse({required List<int> rawData})
      : super.parse(rawData: rawData) {
    rawData = rawData.sublist(5);
    var type = rawData[0];
    if (type == HandshakeType.clientHello.value) {
      handshakeType = HandshakeType.clientHello;
    } else if (type == HandshakeType.serverHello.value) {
      handshakeType = HandshakeType.serverHello;
    }

    var version = rawData.sublist(4, 6);
    if (listsEqual(version, TLSVersion.tls1_0.value)) {
      handshakeTLSVersion = TLSVersion.tls1_0;
    } else if (listsEqual(version, TLSVersion.tls1_1.value)) {
      handshakeTLSVersion = TLSVersion.tls1_1;
    } else if (listsEqual(version, TLSVersion.tls1_2.value)) {
      handshakeTLSVersion = TLSVersion.tls1_2;
    } else if (listsEqual(version, TLSVersion.tls1_3.value)) {
      handshakeTLSVersion = TLSVersion.tls1_3;
    } else {
      throw Exception('unknow tls version. $version');
    }

    random = rawData.sublist(6, 6 + 32);
    sessionID =
        rawData.sublist(39, 39 + 32); // sessionID could not be 32 Bytes.
  }

  @override
  List<int> build() {
    data = handshakeTLSVersion!.value +
        random! +
        [sessionID!.length] +
        sessionID! +
        data;

    var len = Uint8List(4)
      ..buffer.asByteData().setInt32(0, data.length, Endian.big);

    data = [handshakeType!.value] + len.sublist(1) + data;
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

  void setServerName(List<int> serverName) {
    var serverNameLen = Uint8List(2)
      ..buffer.asByteData().setInt16(0, serverName.length, Endian.big);

    var serverNameListLen = Uint8List(2)
      ..buffer.asByteData().setInt16(0, serverName.length + 3, Endian.big);

    for (var i = 0; i < list.length; i++) {
      if (listsEqual(list[i].type, ExtensionType.serverName.value)) {
        list[i].data = serverNameListLen + [0] + serverNameLen + serverName;
        break;
      }
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
  int len = 0;

  ClientCipherSuites.parse({required List<int> rawData}) {
    ByteData byteData =
        ByteData.sublistView(Uint8List.fromList(rawData.sublist(0, 2)));
    len = byteData.getUint16(0, Endian.big);
    data = rawData.sublist(2, 2 + len);
  }

  List<int> build() {
    var len2 = Uint8List(2)..buffer.asByteData().setInt16(0, len, Endian.big);
    return len2 + data;
  }
}

class ClientCompressionMethod {
  List<int> data = [];
  int len = 0;

  ClientCompressionMethod.parse({required List<int> rawData}) {
    len = rawData[0];
    data = rawData.sublist(1, 1 + len);
  }

  List<int> build() {
    return [len] + data;
  }
}

class ClientHello extends Handshake {
  ExtensionList? extensionList;
  ClientCipherSuites? clientCipherSuites;
  ClientCompressionMethod? clientCompressionMethod;

  ClientHello(
      {required super.random,
      super.sessionID,
      required this.clientCipherSuites,
      required this.clientCompressionMethod,
      required this.extensionList,
      super.tlsVersion = TLSVersion.tls1_0})
      : super(handshakeType: HandshakeType.clientHello);

  ClientHello.parse({required List<int> rawData})
      : super.parse(rawData: rawData) {
    rawData = rawData.sublist(5); // TLSBase
    rawData = rawData.sublist(6 + 32 + 1 + 32); // Handshake

    clientCipherSuites = ClientCipherSuites.parse(rawData: rawData);
    rawData = rawData.sublist(2 + clientCipherSuites!.len);

    clientCompressionMethod = ClientCompressionMethod.parse(rawData: rawData);
    rawData = rawData.sublist(1 + clientCompressionMethod!.len);

    extensionList = ExtensionList.parse(rawData: rawData);
  }

  @override
  List<int> build() {
    data = clientCipherSuites!.build() +
        clientCompressionMethod!.build() +
        extensionList!.build();
    return super.build();
  }
}

class ServerHello extends Handshake {
  ExtensionList? extensionList;
  List<int>? serverCompressionMethod;
  List<int>? serverCipherSuite;

  ServerHello(
      {required super.random,
      super.sessionID,
      required this.serverCompressionMethod,
      required this.serverCipherSuite,
      required this.extensionList,
      required super.tlsVersion})
      : super(handshakeType: HandshakeType.serverHello);

  ServerHello.parse({required List<int> rawData})
      : super.parse(rawData: rawData) {
    rawData = rawData.sublist(5); // TLSBase
    rawData = rawData.sublist(6 + 32 + 1 + 32); // Handshake

    serverCipherSuite = rawData.sublist(0, 2);
    serverCompressionMethod = [rawData[3]];
    rawData = rawData.sublist(3);

    extensionList = ExtensionList.parse(rawData: rawData);
  }

  @override
  List<int> build() {
    data =
        serverCipherSuite! + serverCompressionMethod! + extensionList!.build();
    return super.build();
  }
}
