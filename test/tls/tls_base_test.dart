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
  test('clientCompressionMethod', () {
    var clientCompressionMethod = ClientCompressionMethod(data: [1]).build();

    expect(clientCompressionMethod, [1] + [1]);
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
