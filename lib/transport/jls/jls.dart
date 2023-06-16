import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart';
import 'package:proxy/transport/jls/tls/base.dart';

// 4 bytes.
List<int> unixTimeStamp() {
  var time = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  var timeList = Uint8List(4)
    ..buffer.asByteData().setUint32(0, time, Endian.big);
  return timeList;
}

class FakeRandom {
  List<int> n = [];
  List<int> fakeRandom = [];
  List<int> pwd = [];
  List<int> iv = [];
  SecretBox? secretBox;
  final aes = AesGcm.with256bits(nonceLength: 64);

  FakeRandom({required this.pwd, required this.iv}) {
    iv = sha512.convert(iv).bytes;
    pwd = sha256.convert(pwd).bytes;
  }

  Future<List<int>> build({bool userTimeStamp = false}) async {
    n = _randomBytes(userTimeStamp: userTimeStamp);
    var secretKey = await aes.newSecretKeyFromBytes(pwd);
    secretBox = await aes.encrypt(n, secretKey: secretKey, nonce: iv);
    fakeRandom = secretBox!.mac.bytes + secretBox!.cipherText;
    checkLen(fakeRandom, 32);
    return fakeRandom;
  }

  Future<bool> parse({required List<int> rawFakeRandom}) async {
    checkLen(rawFakeRandom, 32);
    fakeRandom = [];
    n = [];
    secretBox = SecretBox(rawFakeRandom.sublist(16),
        nonce: iv, mac: Mac(rawFakeRandom.sublist(0, 16)));
    var secretKey = await aes.newSecretKeyFromBytes(pwd);
    try {
      n = await aes.decrypt(secretBox!, secretKey: secretKey);
    } catch (e) {
      return false;
    }
    fakeRandom = rawFakeRandom;
    return true;
  }

  List<int> _randomBytes({int len = 16, bool userTimeStamp = false}) {
    if (userTimeStamp) {
      return sha224
          .convert(unixTimeStamp() + randomBytes(64))
          .bytes
          .sublist(0, len);
    }
    return randomBytes(len);
  }

  void checkLen(List<int> input, int len) {
    if (input.length != len) {
      throw Exception('wrong len');
    }
  }
}

abstract class JLSHandShakeSide {
  FakeRandom? fakeRandom;
  Handshake? handshake;

  String pwdStr; // from user.
  String ivStr; // from user.

  JLSHandShakeSide({required this.pwdStr, required this.ivStr, this.handshake});

  Future<List<int>> build();
}

class JLSHandShakeClient extends JLSHandShakeSide {
  JLSHandShakeClient(
      {required super.pwdStr, required super.ivStr, required super.handshake});

  @override
  Future<List<int>> build() async {
    handshake!.random =
        await FakeRandom(pwd: utf8.encode(pwdStr), iv: utf8.encode(ivStr))
            .build();
    handshake!.sessionID = randomBytes(32);
    return handshake!.build();
  }
}
