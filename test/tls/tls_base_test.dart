import 'package:proxy/transport/jls/tls/base.dart';
import 'package:proxy/utils/utils.dart';
import 'package:test/test.dart';

void main() {
  test('TLSBase', () {
    var base = TLSBase(
        contentType: ContentType.handshake, tlsVersion: TLSVersion.tls1_0);
    var res = base.build();
    expect(
        res, [ContentType.handshake.value] + TLSVersion.tls1_0.value + [0, 0]);
  });

  test('ChangeSpec', () {
    var changeSpec = ChangeSpec(tlsVersion: TLSVersion.tls1_1);
    var res = changeSpec.build();
    expect(
        res,
        [ContentType.changeCipherSpec.value] +
            TLSVersion.tls1_1.value +
            [0, 1, 1]);
  });

  test('Handshake', () {
    List<int> random = [];
    for (var i = 0; i < 32; i++) {
      random.add(i);
    }
    var handshake = Handshake(
        handshakeType: HandshakeType.clientHello,
        random: random,
        sessionID: random,
        tlsVersion: TLSVersion.tls1_3);

    var handshakeData = handshake.build();

    expect(
        handshakeData,
        [ContentType.handshake.value] +
            TLSVersion.tls1_3.value +
            [0, 71, 1, 0, 0, 67] +
            TLSVersion.tls1_3.value +
            random +
            [32] +
            random);
  });

  test('extension', () {
    var extensions = Extension(type: [0, 0], data: [2]).build();

    expect(extensions, [0, 0, 0, 1, 2]);
  });

  test('extensionList', () {
    var extensionList = ExtensionList(list: [
      Extension(type: [0, 0], data: [2])
    ]).build();

    expect(extensionList, [0, 5] + [0, 0, 0, 1, 2]);
  });

  test('extensionList parse', () {
    var temp = "\x00\x2e"
        "\x00\x33\x00\x24\x00\x1d\x00\x20\xa1\x31\xbc\xa8\x54\xe5\xc9\xdb"
        "\x28\x00\x39\xdc\x5a\x2d\x6d\x10\xf9\x75\xce\x86\x2c\xcd\xe9\x67"
        "\xb6\xdd\x66\xe5\x5f\x74\xee\x0a"
        "\x00\x2b\x00\x02\x03\x04";
    var rawData = List<int>.from(temp.codeUnits);
    var extensionList = ExtensionList.parse(rawData: rawData);
    expect(extensionList.build(), rawData);
  });

  test('clientCompressionMethod', () {
    var clientCompressionMethod = ClientCompressionMethod(data: [1]).build();

    expect(clientCompressionMethod, [1] + [1]);
  });

  test('ServerHello', () {
    List<int> randomB = [];
    for (var i = 0; i < 32; i++) {
      randomB.add(i);
    }
    var serverHello = ServerHello(
        random: randomB,
        sessionID: randomB,
        serverCipherSuite: 0,
        tlsVersion: TLSVersion.tls1_2,
        serverCompressionMethod: 1,
        extensionList: ExtensionList(list: [])).build();

    expect(
        serverHello,
        [ContentType.handshake.value] +
            TLSVersion.tls1_2.value +
            [0, 75] +
            [HandshakeType.serverHello.value] +
            [0, 0, 71] +
            TLSVersion.tls1_2.value +
            randomB +
            [32] +
            randomB +
            [0, 1, 0, 0]);
  });

  test('ClientHello', () {
    List<int> randomB = [];
    for (var i = 0; i < 32; i++) {
      randomB.add(i);
    }

    var clientHello = ClientHello(
        random: randomB,
        sessionID: randomB,
        extensionList: ExtensionList(list: [
          Extension(type: [0, 0], data: [1])
        ]),
        clientCipherSuites: ClientCipherSuites(data: [2, 2]),
        clientCompressionMethod: ClientCompressionMethod(data: [3]),
        tlsVersion: TLSVersion.tls1_2);

    var clientHelloB = clientHello.build();

    expect(
        clientHelloB,
        [ContentType.handshake.value] +
            TLSVersion.tls1_2.value +
            [0, 84] +
            [HandshakeType.clientHello.value] +
            [0, 0, 80] +
            TLSVersion.tls1_2.value +
            randomB +
            [32] +
            randomB +
            [0, 2, 2, 2, 1, 3, 0, 5, 0, 0, 0, 1, 1]);
  });
}
