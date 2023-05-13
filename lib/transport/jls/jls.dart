import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart';

class FakeRandom {
  List<int> customRandom = []; // 4 bytes.
  List<int> nonce = []; // 4 bytes.
  List<int> cipherText =
      []; // 8 bytes = unixTimeStamp(4 bytes) + randomBytes(4 bytes).
  List<int> mac = []; // 16 bytes.
  bool isContainsTimeStamp = false;

  FakeRandom(
      {required this.customRandom,
      required this.nonce,
      required this.cipherText,
      this.isContainsTimeStamp = false,
      required this.mac}) {
    checkLen(customRandom, 4);
  }

  void checkLen(List<int> data, int len) {
    if (data.length != len) {
      throw 'length error';
    }
  }

  FakeRandom.parse(List<int> random) {
    checkLen(random, 32);
    cipherText = random.sublist(0, 8);
    nonce = random.sublist(8, 12);
    mac = random.sublist(12, 28);
    customRandom = random.sublist(28, 32);
  }

  List<int> build32Byte() {
    var res = cipherText + nonce + mac + customRandom;
    checkLen(res, 32);
    return res;
  }
}

// 4 bytes.
List<int> unixTimeStamp() {
  var time = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  var timeList = Uint8List(4)
    ..buffer.asByteData().setUint32(0, time, Endian.big);
  return timeList;
}

class JLSHandShakeSide {
  FakeRandom? fakeRandom; // cipherRandom.
  List<int>? clearRandom;

  String psk; // from user.
  List<int> realPSK = [];
  List<int> otherMac;

  JLSHandShakeSide({required this.psk, this.otherMac = const []}) {
    realPSK = sha256.convert(utf8.encode(psk) + otherMac).bytes;
  }

  Future<SecretBox> encryptWithAES256(List<int> clearText,
      {int nonceLength = 4}) async {
    final aes = AesGcm.with256bits(nonceLength: nonceLength);
    var secretKey = await aes.newSecretKeyFromBytes(realPSK);
    return await aes.encrypt(clearText, secretKey: secretKey);
  }

  Future<List<int>> decryptWithAES256(
      {required List<int> cipherText,
      required List<int> nonce,
      required List<int> mac,
      int nonceLength = 4}) async {
    var secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));

    final aes = AesGcm.with256bits(nonceLength: nonceLength);
    var secretKey = await aes.newSecretKeyFromBytes(realPSK);
    var res = await aes.decrypt(secretBox, secretKey: secretKey);
    return res;
  }

  // genarate clearRandom and fakeRandom.
  Future<void> encrypt({isContainsTimeStamp = false}) async {
    if (isContainsTimeStamp) {
      clearRandom = randomBytes(4) + unixTimeStamp();
    } else {
      clearRandom = randomBytes(8);
    }
    var secretBox = await encryptWithAES256(clearRandom!);
    fakeRandom = FakeRandom(
        customRandom: randomBytes(4),
        nonce: secretBox.nonce,
        cipherText: secretBox.cipherText,
        mac: secretBox.mac.bytes);
  }

  // parse fakeRandom to clearRandom.
  Future<void> decrypt(List<int> encryptedRandom) async {
    fakeRandom = FakeRandom.parse(encryptedRandom);
    clearRandom = await decryptWithAES256(
      mac: fakeRandom!.mac,
      nonce: fakeRandom!.nonce,
      cipherText: fakeRandom!.cipherText,
    );
  }
}
