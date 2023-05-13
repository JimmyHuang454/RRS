import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart';

class FakeHandShake {
  List<int> handShakeContent = [];
  List<int> id = [];

  FakeHandShake({required this.handShakeContent});

  // with no random.
  List<int> rawContent() {
    return handShakeContent;
  }

  List<int> contentWithRandom({required List<int> random}) {
    return utf8
        .decode(handShakeContent)
        .replaceFirst('{random}', random.toString())
        .codeUnits;
  }
}

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
    if (customRandom.length != 4) {
      throw 'length error';
    }
  }

  FakeRandom.parse(List<int> random) {
    if (random.length != 32) {
      throw 'length error';
    }
    cipherText = random.sublist(0, 8);
    nonce = random.sublist(8, 12);
    mac = random.sublist(12, 28);
    customRandom = random.sublist(28, 32);
  }

  List<int> build32Byte() {
    var res = cipherText + nonce + mac + customRandom;
    if (res.length != 32) {
      throw 'length error';
    }
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
  FakeRandom? fakeRandom;

  String psk;
  List<int> realPSK = [];
  List<int> otherMac;

  List<int>? clearRandom;

  JLSHandShakeSide({required this.psk, this.otherMac = const []}) {
    realPSK = sha256.convert(utf8.encode(psk) + otherMac).bytes;
  }

  Future<SecretBox> encryptWithAES256(List<int> key, List<int> clearText,
      {int nonceLength = 4}) async {
    final aes = AesGcm.with256bits(nonceLength: nonceLength);
    var secretKey = await aes.newSecretKeyFromBytes(key);
    return await aes.encrypt(clearText, secretKey: secretKey);
  }

  Future<List<int>> decryptWithAES256(
      {required List<int> key,
      required List<int> cipherText,
      required List<int> nonce,
      required List<int> mac,
      int nonceLength = 4}) async {
    var secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));

    final aes = AesGcm.with256bits(nonceLength: nonceLength);
    var secretKey = await aes.newSecretKeyFromBytes(key);
    var res = await aes.decrypt(secretBox, secretKey: secretKey);
    return res;
  }

  Future<void> encrypt({isContainsTimeStamp = false}) async {
    if (isContainsTimeStamp) {
      clearRandom = randomBytes(4) + unixTimeStamp();
    } else {
      clearRandom = randomBytes(8);
    }
    var secretBox = await encryptWithAES256(realPSK, clearRandom!);
    fakeRandom = FakeRandom(
        customRandom: randomBytes(4),
        nonce: secretBox.nonce,
        cipherText: secretBox.cipherText,
        mac: secretBox.mac.bytes);
  }

  Future<void> decrypt(List<int> encryptedRandom) async {
    fakeRandom = FakeRandom.parse(encryptedRandom);
    clearRandom = await decryptWithAES256(
      key: realPSK,
      mac: fakeRandom!.mac,
      nonce: fakeRandom!.nonce,
      cipherText: fakeRandom!.cipherText,
    );
  }
}
