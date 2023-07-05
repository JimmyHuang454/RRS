import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart' as cryptography;
import 'package:cryptography/helpers.dart';
import 'package:proxy/utils/utils.dart';

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

  test('AES2.', () async {
    var se = crypto.sha256.convert([1]).bytes;

    final algorithm = cryptography.AesGcm.with256bits(nonceLength: 64);
    var secretKey = await algorithm.newSecretKeyFromBytes(se);
    final nonce = [174, 148, 142, 187, 203, 70, 173, 30, 15, 35, 13, 130];

    // Encrypt
    final secretBox = await algorithm.encrypt(
      [2],
      secretKey: secretKey,
      nonce: nonce,
    );
    print('pwd: $se len: ${se.length}');
    print('Nonce: ${secretBox.nonce} len: ${secretBox.nonce.length}');
    print('MAC: ${secretBox.mac.bytes} len: ${secretBox.mac.bytes.length}');
    print(
        'Ciphertext: ${secretBox.cipherText} len: ${secretBox.cipherText.length}');
  });

  test('x25519.', () async {
    final algorithm = cryptography.X25519();

    final aliceKeyPair = await algorithm.newKeyPair();
    final alicePublicKey = await aliceKeyPair.extractPublicKey();

    final bobKeyPair = await algorithm.newKeyPair();
    final bobPublicKey = await bobKeyPair.extractPublicKey();
    var bobPublicKey2 = cryptography.SimplePublicKey(randomBytes(32),
        type: cryptography.KeyPairType.x25519);

    final sharedSecretKey1 = await algorithm.sharedSecretKey(
      keyPair: aliceKeyPair,
      remotePublicKey: bobPublicKey,
    );

    final sharedSecretKey2 = await algorithm.sharedSecretKey(
      keyPair: bobKeyPair,
      remotePublicKey: alicePublicKey,
    );

    expect(await sharedSecretKey1.extractBytes(),
        await sharedSecretKey2.extractBytes());
  });

  test('x25519 same res.', () async {
    final algorithm = cryptography.X25519();

    // We need the private key pair of Alice.
    final aliceKeyPair = await algorithm.newKeyPair();

    // We need only public key of Bob.
    final bobKeyPair = await algorithm.newKeyPair();

    final bobPublicKey = await bobKeyPair.extractPublicKey();
    var temp = bobPublicKey.bytes;
    var bobPublicKey2 = cryptography.SimplePublicKey(randomBytes(32),
        type: cryptography.KeyPairType.x25519);

    // We can now calculate a 32-byte shared secret key.
    final sharedSecretKey = await algorithm.sharedSecretKey(
      keyPair: aliceKeyPair,
      remotePublicKey: bobPublicKey2,
    );
    // print(await sharedSecretKey.extractBytes());
  });

  test('hmac.', () async {
    final message = [1, 2, 3];
    final secretKey = cryptography.SecretKey([4, 5, 6]);

    // In our example, we calculate HMAC-SHA256
    final hmac = cryptography.Hmac.sha256();
    final mac = await hmac.calculateMac(
      message,
      secretKey: secretKey,
    );
    // print(mac.bytes);
  });
}

enum Bar<T extends Object> {
  tls1_3<List<int>>([0x3, 0x1]);

  const Bar(this.value);
  final T value;
}
