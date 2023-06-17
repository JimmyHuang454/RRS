import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart';
import 'package:proxy/transport/jls/tls/base.dart';
import 'package:proxy/utils/utils.dart';

class FakeRandom {
  List<int> n = [];
  List<int> fakeRandom = [];
  List<int> pwd = [];
  List<int> iv = [];
  SecretBox? secretBox;

  // iv len == 64 bytes.
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

class JLSHandShakeSide {
  List<int> data = [];

  List<int> iv = [];
  List<int> pwd = [];
  SecretKey? finalPWD;

  FakeRandom? fakeRandom;
  Handshake? local;
  Handshake? remote;

  final aes = AesGcm.with256bits(nonceLength: 64);
  SecretKey? sharedSecretKey;
  SimplePublicKey? simplePublicKey; // remote pub key.
  SimpleKeyPair? keyPair; // local keyPair.
  final supportGroup = X25519(); // only x25519.

  int sendID = 0;
  int receiveID = 0;

  JLSHandShakeSide(
      {required String pwdStr, required String ivStr, this.local}) {
    pwd = utf8.encode(pwdStr);
    iv = utf8.encode(ivStr);
  }

  Future<void> getSecretKey() async {
    // remote should be init first.
    // input other side pubKey then generate sharedSecretKey.
    simplePublicKey = SimplePublicKey(remote!.extensionList!.getKeyShare(),
        type: KeyPairType.x25519);

    sharedSecretKey = await supportGroup.sharedSecretKey(
      keyPair: keyPair!,
      remotePublicKey: simplePublicKey!,
    );
    finalPWD = await aes.newSecretKeyFromBytes(
        sha256.convert(pwd + await sharedSecretKey!.extractBytes()).bytes);
  }

  Future<void> setKeyShare() async {
    keyPair = await supportGroup.newKeyPair();
    var pubKey = await keyPair!.extractPublicKey();
    local!.extensionList!.setKeyShare(pubKey.bytes);
  }

  Future<ApplicationData> send(List<int> data) async {
    var id = Uint8List(4)..buffer.asByteData().setUint32(0, sendID, Endian.big);

    var iv2 = sha512.convert(iv + id).bytes;
    var secretBox = await aes.encrypt(data, secretKey: finalPWD!, nonce: iv2);

    sendID += 1;
    return ApplicationData(data: secretBox.cipherText + secretBox.mac.bytes);
  }

  Future<List<int>> receive(ApplicationData input) async {
    var id = Uint8List(4)
      ..buffer.asByteData().setUint32(0, receiveID, Endian.big);
    var iv2 = sha512.convert(iv + id).bytes;
    var secretBox = SecretBox(input.data.sublist(0, input.data.length - 16),
        nonce: iv2, mac: Mac(input.data.sublist(input.data.length - 16)));
    List<int> res = [];

    try {
      res = await aes.decrypt(secretBox, secretKey: finalPWD!);
    } catch (e) {
      return [];
    }
    receiveID += 1;
    return res;
  }

  Future<List<int>> build() async {
    return data;
  }

  Future<bool> check({required Handshake inputRemote}) async {
    remote = inputRemote;
    return false;
  }
}

class JLSHandShakeClient extends JLSHandShakeSide {
  ServerHello? serverHello;

  JLSHandShakeClient(
      {required super.pwdStr, required super.ivStr, required super.local});

  @override
  Future<bool> check({required Handshake inputRemote}) async {
    remote = inputRemote;

    var random = inputRemote.random!;
    inputRemote.random = zeroList();
    await getSecretKey();

    // iv == iv + clientHello(Not 0 random) + serverHello(0 random)
    fakeRandom = FakeRandom(
        pwd: pwd + await sharedSecretKey!.extractBytes(),
        iv: iv + data + inputRemote.build());
    inputRemote.random = random; // !! must restore.
    var isValid = await fakeRandom!.parse(rawFakeRandom: random);
    return isValid;
  }

  @override
  Future<List<int>> build() async {
    local!.random = zeroList();
    local!.sessionID = randomBytes(32);
    await setKeyShare();

    data = local!.build();

    // iv == iv + clientHello(0 random).
    fakeRandom = FakeRandom(pwd: pwd, iv: iv + data);
    local!.random = await fakeRandom!.build();
    data = local!.build();
    return data;
  }
}

class JLSHandShakeServer extends JLSHandShakeSide {
  JLSHandShakeServer(
      {required super.pwdStr, required super.ivStr, required super.local});

  @override
  Future<bool> check({required Handshake inputRemote}) async {
    remote = inputRemote;
    var random = inputRemote.random!;

    inputRemote.random = zeroList();
    fakeRandom = FakeRandom(pwd: pwd, iv: iv + inputRemote.build());
    inputRemote.random = random; // !! must restore.

    var isValid = await fakeRandom!.parse(rawFakeRandom: random);
    return isValid;
  }

  @override
  Future<List<int>> build() async {
    local!.random = zeroList();
    local!.sessionID = remote!.sessionID;
    await setKeyShare();
    await getSecretKey();
    data = local!.build();

    // iv == iv + clientHello(Not 0 random) + serverHello(0 random)
    fakeRandom = FakeRandom(
        pwd: pwd + await sharedSecretKey!.extractBytes(),
        iv: iv + remote!.build() + data);
    local!.random = await fakeRandom!.build();
    data = local!.build();
    return data;
  }
}
