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
  tls1_2([0x03, 0x03]),
  tls1_3([0x03, 0x04]);

  const TLSVersion(this.value);
  final List<int> value;
}

enum CipherSuites {
// ignore: constant_identifier_names
  TLS_AES_128_GCM_SHA256([0x13, 0x01]),
// ignore: constant_identifier_names
  TLS_AES_256_GCM_SHA384([0x13, 0x02]);

  const CipherSuites(this.value);
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

  TLSBase({this.tlsVersion = TLSVersion.tls1_2, required this.contentType});

  List<int> build(List<int> playload) {
    var len = Uint8List(2)
      ..buffer.asByteData().setInt16(0, playload.length, Endian.big);
    return [contentType.value] + tlsVersion.value + len + playload;
  }
}

class Handshake extends TLSBase {
  HandshakeType handshakeType;
  List<int>? random;
  List<int>? sessionID;

  Handshake({required this.handshakeType, this.random, this.sessionID})
      : super(
            tlsVersion: TLSVersion.tls1_2, contentType: ContentType.handshake) {
    random ??= randomBytes(32);
    sessionID ??= randomBytes(32);
  }

  @override
  List<int> build(List<int> playload) {
    playload = random! + [sessionID!.length] + sessionID! + playload;

    var len = Uint8List(4)
      ..buffer.asByteData().setInt32(0, playload.length, Endian.big);

    var res =
        [handshakeType.value] + len.sublist(1) + tlsVersion.value + playload;
    return super.build(res);
  }
}

class Extension {
  ExtensionType extensionType;

  Extension({required this.extensionType});

  List<int> build(List<int> playload) {
    var len = Uint8List(2)
      ..buffer.asByteData().setInt16(0, playload.length, Endian.big);
    return extensionType.value + len + playload;
  }
}

class SuppertedVersions extends Extension {
  int len;
  List<TLSVersion> tlsVersionList;

  SuppertedVersions({required this.len, required this.tlsVersionList})
      : super(extensionType: ExtensionType.supportedVersion);

  @override
  List<int> build(List<int> playload) {
    var temp = [tlsVersionList.length * 2];
    for (var i = 0, len = tlsVersionList.length; i < len; ++i) {
      temp += tlsVersionList[i].value;
    }
    return build(temp);
  }
}

class ClientHandShake extends Handshake {
  List<Extension> extensionList;
  List<CipherSuites> cipherSuites;

  ClientHandShake(
      {super.random,
      super.sessionID,
      this.extensionList = const [],
      this.cipherSuites = const []})
      : super(handshakeType: HandshakeType.clientHello);

  @override
  List<int> build(List<int> playload) {
    var cipherSuitesLength = Uint8List(2)
      ..buffer.asByteData().setInt16(0, cipherSuites.length, Endian.big);

    playload = cipherSuitesLength;

    for (var i = 0, len = cipherSuites.length; i < len; ++i) {
      playload += cipherSuites[i].value;
    }

    List<int> extensions = [];
    for (var i = 0, len = extensionList.length; i < len; ++i) {
      extensions += extensionList[i].build([]);
    }

    var extensionLength = Uint8List(2)
      ..buffer.asByteData().setInt16(0, extensions.length, Endian.big);

    playload += extensionLength + extensions;

    var playloadLen = Uint8List(3)
      ..buffer.asByteData().setInt32(0, playload.length, Endian.big);

    var res = [handshakeType.value] + playloadLen + tlsVersion.value + playload;

    return super.build(res);
  }
}
