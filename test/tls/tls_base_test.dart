import 'package:proxy/transport/jls/tls/base.dart';
import 'package:proxy/utils/utils.dart';
import 'package:test/test.dart';

void main() {
  List<int> randomB = [];
  for (var i = 0; i < 32; i++) {
    randomB.add(i);
  }

  test('empty TLSBase', () {
    var base = TLSBase(
        contentType: ContentType.handshake, tlsVersion: TLSVersion.tls1_0);
    var res = base.build();
    expect(
        res, [ContentType.handshake.value] + TLSVersion.tls1_0.value + [0, 0]);
    expect(res, [0x16, 0x03, 0x01] + [0, 0]);
  });

  test('TLSBase', () {
    var base = TLSBase(
        contentType: ContentType.handshake, tlsVersion: TLSVersion.tls1_0);
    base.data = [1, 2];
    var res = base.build();
    expect(res,
        [ContentType.handshake.value] + TLSVersion.tls1_0.value + [0, 2, 1, 2]);
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
        handshakeTLSVersion: TLSVersion.tls1_0,
        tlsVersion: TLSVersion.tls1_3);

    var handshakeData = handshake.build();

    expect(
        handshakeData,
        [ContentType.handshake.value] +
            TLSVersion.tls1_3.value +
            [0, 71, 1, 0, 0, 67] +
            TLSVersion.tls1_0.value +
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

  test('cipherSuitLen parse.', () {
    var temp =
        "\x13\x03\x13\x01\x13\x02\xcc\xa9\xcc\xa8\xc0\x2b\xc0\x2f\xc0\x2c"
        "\xc0\x30\xc0\x09\xc0\x13\xc0\x0a\xc0\x14\x00\x9c\x00\x9d\x00\x2f"
        "\x00\x35\x00\x0a";
    var res = ClientCipherSuites(data: temp.codeUnits);
    expect(res.build(), [0, 36] + temp.codeUnits);
  });

  test('clientHello parse.', () {
    var temp =
        "\x16\x03\x01\x00\xf3\x01\x00\x00\xef\x03\x03\x98\x32\x6e\xb1\xde"
        "\xea\xe1\x9b\xd2\x96\x7c\xca\x32\xf9\x0e\x89\x99\x8e\xc9\x6f\x7c"
        "\x68\x76\x96\x5d\x49\x5f\xfc\xab\xc4\xd2\x4b\x20\xba\xa5\x77\xce"
        "\xb7\xc6\x18\x4c\x81\x98\xf2\x74\x7e\xba\x07\x29\x71\x95\x61\x90"
        "\x2e\x8b\x6d\x86\x83\xcf\x0e\xc8\x48\x7f\x5f\x95\x00\x24\x13\x03"
        "\x13\x01\x13\x02\xcc\xa9\xcc\xa8\xc0\x2b\xc0\x2f\xc0\x2c\xc0\x30"
        "\xc0\x09\xc0\x13\xc0\x0a\xc0\x14\x00\x9c\x00\x9d\x00\x2f\x00\x35"
        "\x00\x0a\x01\x00\x00\x82\x00\x00\x00\x0e\x00\x0c\x00\x00\x09\x75"
        "\x69\x66\x30\x33\x2e\x74\x6f\x70\x00\x17\x00\x00\xff\x01\x00\x01"
        "\x00\x00\x0a\x00\x08\x00\x06\x00\x1d\x00\x17\x00\x18\x00\x0b\x00"
        "\x02\x01\x00\x00\x23\x00\x00\x00\x0d\x00\x14\x00\x12\x04\x03\x08"
        "\x04\x04\x01\x05\x03\x08\x05\x05\x01\x08\x06\x06\x01\x02\x01\x00"
        "\x33\x00\x26\x00\x24\x00\x1d\x00\x20\x1d\xa8\xaf\xb5\x94\x32\x95"
        "\x87\x14\x04\x79\xbf\xff\x96\x0e\xcf\x4d\xd5\x16\xa4\xfd\xf9\x6c"
        "\x72\x57\x85\xf4\xff\xf9\x42\x05\x7c\x00\x2d\x00\x02\x01\x01\x00"
        "\x2b\x00\x05\x04\x03\x04\x03\x03";

    var rawData = List<int>.from(temp.codeUnits);


    var res = ClientHello.parse(rawData: rawData);
    expect(rawData, res.build());

    var radom2 =
        "\x98\x32\x6e\xb1\xde\xea\xe1\x9b\xd2\x96\x7c\xca\x32\xf9\x0e\x89"
        "\x99\x8e\xc9\x6f\x7c\x68\x76\x96\x5d\x49\x5f\xfc\xab\xc4\xd2\x4b";
    var start = indexOfElements(rawData, radom2.codeUnits);
    rawData.replaceRange(start, start + 32, randomB);

    var sessionID2 =
        "\xba\xa5\x77\xce\xb7\xc6\x18\x4c\x81\x98\xf2\x74\x7e\xba\x07\x29"
        "\x71\x95\x61\x90\x2e\x8b\x6d\x86\x83\xcf\x0e\xc8\x48\x7f\x5f\x95";
    start = indexOfElements(rawData, sessionID2.codeUnits);
    rawData.replaceRange(start, start + 32, randomB);

    res.random = randomB;
    res.sessionID = randomB;
    expect(rawData, res.build());
  });
}
