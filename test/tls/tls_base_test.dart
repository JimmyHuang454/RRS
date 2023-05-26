import 'package:proxy/transport/jls/tls/base.dart';
import 'package:test/test.dart';

void main() {
  test('tls base', () {
    var temp = TLSBase(contentType: ContentType.handshake);
    var res = temp.build([1]);
    expect(res, [0x16, 0x3, 0x3, 0, 1, 1]);

    return;
    temp = Handshake(handshakeType: HandshakeType.clientHello);
    res = temp.build([]);
    expect(res, [0x16, 0x3, 0x3, 0, 7, 1, 0, 0, 1, 0x3, 0x3, 0]);

    temp = ClientHandShake(cipherSuites: [CipherSuites.TLS_AES_128_GCM_SHA256]);
    res = temp.build([]);
    print(res);
    expect(res, [0x16, 0x3, 0x3, 0, 6, 1, 0, 1, 0x3, 0x3, 0]);
  });
}
