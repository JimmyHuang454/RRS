import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart';

class FakeRandom {
  List<int> customRandom = []; // 4 bytes.
  List<int> cipherText =
      []; // 8 bytes = unixTimeStamp(4 bytes) + randomBytes(4 bytes).
  List<int> mac = []; // 16 bytes.

  FakeRandom(
      {required this.customRandom,
      required this.cipherText,
      required this.mac}) {
    checkLen(customRandom, 4);
    checkLen(cipherText, 12);
    checkLen(mac, 16);
  }

  void checkLen(List<int> data, int len) {
    if (data.length != len) {
      throw 'length error';
    }
  }

  FakeRandom.parse(List<int> random) {
    checkLen(random, 32);
    customRandom = random.sublist(0, 4);
    cipherText = random.sublist(4, 16);
    mac = random.sublist(16, 32);
  }

  List<int> build32Byte() {
    var res = customRandom + cipherText + mac;
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
  String nonceStr; // from user.
  List<int> nonce = [];
  List<int> realPWD = [];
  List<int> otherMac;
  List<int> _pwd = [];
  final aes = AesGcm.with256bits(nonceLength: 64);

  JLSHandShakeSide(
      {required this.psk, required this.nonceStr, this.otherMac = const []}) {
    _pwd = utf8.encode(psk) + otherMac;
    nonce = sha512.convert(utf8.encode(nonceStr)).bytes;
  }

  List<int> buildPWD(List<int> customRandom) {
    return realPWD = sha256.convert(_pwd + customRandom).bytes;
  }

  List<int> buildRandomBytes({int len = 12, bool isContainsTimeStamp = false}) {
    if (isContainsTimeStamp) {
      return sha224
          .convert(unixTimeStamp() + randomBytes(64))
          .bytes
          .sublist(0, len);
    }
    return randomBytes(len);
  }

  Future<SecretBox> encryptWithAES256({
    required List<int> clearText,
    required List<int> pwd,
  }) async {
    var secretKey = await aes.newSecretKeyFromBytes(pwd);
    return await aes.encrypt(clearText, secretKey: secretKey, nonce: nonce);
  }

  Future<List<int>> decryptWithAES256(
      {required List<int> cipherText,
      required List<int> mac,
      required List<int> pwd}) async {
    var secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));

    var secretKey = await aes.newSecretKeyFromBytes(pwd);
    var res = await aes.decrypt(secretBox, secretKey: secretKey);
    return res;
  }

  // genarate clearRandom and fakeRandom.
  Future<void> encrypt({isContainsTimeStamp = false}) async {
    List<int> timestamp = randomBytes(4);
    if (isContainsTimeStamp) {
      timestamp = unixTimeStamp();
    }

    clearRandom = buildRandomBytes(len: 12, isContainsTimeStamp: true);
    var secretBox = await encryptWithAES256(
        clearText: clearRandom!, pwd: buildPWD(timestamp));

    fakeRandom = FakeRandom(
        customRandom: timestamp,
        cipherText: secretBox.cipherText,
        mac: secretBox.mac.bytes);
  }

  // parse fakeRandom to clearRandom.
  Future<void> decrypt(List<int> encryptedRandom) async {
    fakeRandom = FakeRandom.parse(encryptedRandom);
    clearRandom = await decryptWithAES256(
        mac: fakeRandom!.mac,
        cipherText: fakeRandom!.cipherText,
        pwd: buildPWD(fakeRandom!.customRandom));
  }
}
