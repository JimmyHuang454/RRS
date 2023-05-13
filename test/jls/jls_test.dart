import 'package:proxy/transport/jls/jls.dart';
import 'package:quiver/collection.dart';

import 'package:test/test.dart';

void main() {
  test('AES.', () async {
    var temp = JLSHandShakeSide(psk: 'abc');
    await temp.encrypt();
    var fakeRandomObj = temp.fakeRandom!;
    expect(fakeRandomObj.nonce.length, 4);
    expect(fakeRandomObj.customRandom.length, 4);
    expect(fakeRandomObj.cipherText.length, 8);
    expect(fakeRandomObj.mac.length, 16);

    var fakeRandom1 = fakeRandomObj.build32Byte();
    expect(
        fakeRandom1,
        fakeRandomObj.cipherText +
            fakeRandomObj.nonce +
            fakeRandomObj.mac +
            fakeRandomObj.customRandom);
    var fakeRandom2 = fakeRandomObj.build32Byte();
    expect(fakeRandom1, fakeRandom2);

    await temp.encrypt();
    fakeRandomObj = temp.fakeRandom!;
    fakeRandom2 = fakeRandomObj.build32Byte();
    expect(listsEqual(fakeRandom1, fakeRandom2), false);
  });

  test('JLSHandShakeSide FakeRandom with unixTimeStamp.', () async {
    var client = JLSHandShakeSide(psk: 'abc');
    await client.encrypt(isContainsTimeStamp: true);
    client.fakeRandom!.build32Byte();
  });

  test('JLSHandShakeSide encrypt and decrypt.', () async {
    var client = JLSHandShakeSide(psk: 'abc');
    await client.encrypt();

    var server = JLSHandShakeSide(psk: 'abc');
    await server.decrypt(client.fakeRandom!.build32Byte());

    expect(client.realPSK, server.realPSK);
    expect(client.clearRandom, server.clearRandom);

    var server2 = JLSHandShakeSide(psk: '123');
    expect(() async => await server2.decrypt(client.fakeRandom!.build32Byte()),
        throwsException);

    var server3 = JLSHandShakeSide(psk: 'abc', otherMac: [1]);
    expect(() async => await server3.decrypt(client.fakeRandom!.build32Byte()),
        throwsException);
  });
}
