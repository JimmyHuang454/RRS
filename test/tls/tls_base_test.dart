import 'package:proxy/transport/jls/tls/base.dart';
import 'package:proxy/utils/utils.dart';
import 'package:test/test.dart';

void main() {
  List<int> randomB = [];
  for (var i = 0; i < 32; i++) {
    randomB.add(i);
  }

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

  test('clientHello parse.', () {
    var temp =
        "\x16\x03\x01\x02\x00\x01\x00\x01\xfc\x03\x03\xbb\xd3\x7d\xa2\x01"
        "\x0c\x20\x36\x60\xb4\xb6\xfe\x47\xb2\x35\xc2\x7b\x96\x66\x8d\xa0"
        "\x1b\x66\x24\xea\x3a\xfa\x76\xf1\x2c\xbc\x14\x20\x77\x52\x3c\x28"
        "\x02\x4a\x9a\xf3\x0a\x98\x26\xd5\x3e\x1f\x80\xa3\xa7\xcf\x3a\x0d"
        "\x31\xd9\xe7\x26\x1f\x65\xec\xa1\xf1\xdd\x0f\x3d\x00\x20\x9a\x9a"
        "\x13\x01\x13\x02\x13\x03\xc0\x2b\xc0\x2f\xc0\x2c\xc0\x30\xcc\xa9"
        "\xcc\xa8\xc0\x13\xc0\x14\x00\x9c\x00\x9d\x00\x2f\x00\x35\x01\x00"
        "\x01\x93\xaa\xaa\x00\x00\x00\x1b\x00\x03\x02\x00\x02\x00\x12\x00"
        "\x00\x00\x05\x00\x05\x01\x00\x00\x00\x00\x00\x0a\x00\x0a\x00\x08"
        "\x9a\x9a\x00\x1d\x00\x17\x00\x18\x00\x17\x00\x00\x00\x0d\x00\x12"
        "\x00\x10\x04\x03\x08\x04\x04\x01\x05\x03\x08\x05\x05\x01\x08\x06"
        "\x06\x01\xff\x01\x00\x01\x00\x00\x0b\x00\x02\x01\x00\x00\x00\x00"
        "\x1b\x00\x19\x00\x00\x16\x68\x65\x63\x74\x6f\x72\x73\x74\x61\x74"
        "\x69\x63\x2e\x62\x61\x69\x64\x75\x2e\x63\x6f\x6d\x00\x33\x00\x2b"
        "\x00\x29\x9a\x9a\x00\x01\x00\x00\x1d\x00\x20\xb0\xc9\x82\x1b\xf2"
        "\x9d\x66\x5d\xbb\xcc\x9e\x11\x77\x21\xb3\x0e\x57\x05\xd6\x2d\x66"
        "\xa8\x09\x32\xbf\xed\xc9\x6c\x52\xae\x00\x49\x00\x2d\x00\x02\x01"
        "\x01\x00\x2b\x00\x07\x06\x6a\x6a\x03\x04\x03\x03\x44\x69\x00\x05"
        "\x00\x03\x02\x68\x32\x00\x23\x00\x00\x00\x10\x00\x0e\x00\x0c\x02"
        "\x68\x32\x08\x68\x74\x74\x70\x2f\x31\x2e\x31\x1a\x1a\x00\x01\x00"
        "\x00\x15\x00\xc1\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
        "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
        "\x00\x00\x00\x00\x00";
    var rawData = List<int>.from(temp.codeUnits);
    ClientHello.parse(rawData: rawData);
  });
}
