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

  test('Handshake', () {
    var handshake = Handshake(
        handshakeType: HandshakeType.clientHello,
        random: [1],
        sessionID: [2],
        tlsVersion: TLSVersion.tls1_3);

    var handshakeData = handshake.build();

    var base = [ContentType.handshake.value] + TLSVersion.tls1_3.value + [0, 9];
    expect(
        handshakeData,
        base +
            [HandshakeType.clientHello.value] +
            [0, 0, 5] +
            TLSVersion.tls1_3.value +
            [1, 1, 2]);
  });
}
