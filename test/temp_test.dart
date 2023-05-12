import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

import 'package:test/test.dart';

void main() {
  test('temp test.', () async {
    var temp = Uri.parse('http://127.0.0.1');
    expect(temp.host, '127.0.0.1');

    temp = Uri.parse('127.0.0.1');
    expect(temp.host, '');

    temp = Uri.parse('www.abc.com');
    expect(temp.host, '');

    temp = Uri.parse('abc.com');
    expect(temp.host, '');

    temp = Uri.parse('abc');
    expect(temp.host, '');

    temp = Uri.parse('fuck://abc');
    expect(temp.host, 'abc');

    temp = Uri.parse('fuck://abc.cn');
    expect(temp.host, 'abc.cn');
  });

  test('AES.', () async {
    var time = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    print(time);
    var message = Uint8List(4)
      ..buffer.asByteData().setUint32(0, time, Endian.big);

    var se = sha256.convert([1, 2, 3]).toString().codeUnits;
    print(se.length);

    List<int> se2 = [];
    for (var i = 0; i < 32; ++i) {
      se2.add(i);
    }
    // message = se2;

    final algorithm = AesGcm.with256bits(nonceLength: 4);
    var secretKey = await algorithm.newSecretKeyFromBytes(se2);
    final nonce = algorithm.newNonce();

    // Encrypt
    final secretBox = await algorithm.encrypt(
      message,
      secretKey: secretKey,
      nonce: nonce,
    );
    print('Nonce: ${secretBox.nonce} len: ${secretBox.nonce.length}');
    print(
        'Ciphertext: ${secretBox.cipherText} len: ${secretBox.cipherText.length}');
    print('MAC: ${secretBox.mac.bytes} len: ${secretBox.mac.bytes.length}');

    var mys = SecretBox(secretBox.cipherText,
        nonce: secretBox.nonce, mac: secretBox.mac);
    // Decrypt
    final clearText = await algorithm.decrypt(
      mys,
      secretKey: secretKey,
    );

    ByteData byteData = ByteData.sublistView(Uint8List.fromList(message));
    var time2 = byteData.getUint32(0, Endian.big);
    print(time2);
  });
}
