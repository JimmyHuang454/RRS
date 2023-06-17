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
  FakeRandom? fakeRandom;
  Handshake? format; // format
  List<int> data = [];
  List<int> pwd = [];
  late SecretKey finnallyPWD;
  List<int> iv = [];

  final aes = AesGcm.with256bits(nonceLength: 64);
  Handshake? handshake;

  SecretKey? secretKey;
  SimplePublicKey? simplePublicKey;

  final supportGroup = X25519();
  SimpleKeyPair? keyPair;

  int sendID = 0;
  int receiveID = 0;

  JLSHandShakeSide(
      {required String pwdStr, required String ivStr, this.format}) {
    pwd = utf8.encode(pwdStr);
    iv = utf8.encode(ivStr);
  }

  Future<void> getSecretKey() async {
    // handshake should be init.
    // input other side pubKey then generate sharedSecretKey.
    simplePublicKey = SimplePublicKey(handshake!.extensionList!.getKeyShare(),
        type: KeyPairType.x25519);

    secretKey = await supportGroup.sharedSecretKey(
      keyPair: keyPair!,
      remotePublicKey: simplePublicKey!,
    );
    finnallyPWD = await aes.newSecretKeyFromBytes(
        sha256.convert(pwd + await secretKey!.extractBytes()).bytes);
  }

  Future<void> setKeyShare() async {
    keyPair = await supportGroup.newKeyPair();
    var pubKey = await keyPair!.extractPublicKey();
    format!.extensionList!.setKeyShare(pubKey.bytes);
  }

  Future<ApplicationData> send(List<int> data) async {
    var id = Uint8List(4)..buffer.asByteData().setUint32(0, sendID, Endian.big);

    var iv2 = sha512.convert(iv + id).bytes;
    var secretBox = await aes.encrypt(data, secretKey: finnallyPWD, nonce: iv2);

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
      res = await aes.decrypt(secretBox, secretKey: finnallyPWD);
    } catch (e) {
      return [];
    }
    receiveID += 1;
    return res;
  }
}

class JLSHandShakeClient extends JLSHandShakeSide {
  ServerHello? serverHello;

  JLSHandShakeClient(
      {required super.pwdStr, required super.ivStr, required super.format});

  Future<bool> checkServer({required ServerHello inputServerHello}) async {
    handshake = inputServerHello;
    var random = inputServerHello.random!;
    inputServerHello.random = zeroList();
    await getSecretKey();

    // iv == iv + clientHello(Not 0 random) + serverHello(0 random)
    fakeRandom = FakeRandom(
        pwd: pwd + await secretKey!.extractBytes(),
        iv: iv + data + inputServerHello.build());
    inputServerHello.random = random; // !! must restore.
    var isValid = await fakeRandom!.parse(rawFakeRandom: random);
    return isValid;
  }

  Future<List<int>> build() async {
    format!.random = zeroList();
    format!.sessionID = randomBytes(32);
    await setKeyShare();

    data = format!.build();

    // iv == iv + clientHello(0 random).
    fakeRandom = FakeRandom(pwd: pwd, iv: iv + data);
    format!.random = await fakeRandom!.build();
    data = format!.build();
    return data;
  }
}

class JLSHandShakeServer extends JLSHandShakeSide {
  JLSHandShakeServer(
      {required super.pwdStr, required super.ivStr, required super.format});

  Future<bool> checkClient({required ClientHello inputClientHello}) async {
    handshake = inputClientHello;
    var random = inputClientHello.random!;

    inputClientHello.random = zeroList();
    fakeRandom = FakeRandom(pwd: pwd, iv: iv + inputClientHello.build());
    inputClientHello.random = random; // !! must restore.

    var isValid = await fakeRandom!.parse(rawFakeRandom: random);
    return isValid;
  }

  // build after check.
  Future<List<int>> build() async {
    format!.random = zeroList();
    format!.sessionID = handshake!.sessionID;
    await setKeyShare();
    await getSecretKey();
    data = format!.build();

    // iv == iv + clientHello(Not 0 random) + serverHello(0 random)
    fakeRandom = FakeRandom(
        pwd: pwd + await secretKey!.extractBytes(),
        iv: iv + handshake!.build() + data);
    format!.random = await fakeRandom!.build();
    data = format!.build();
    return data;
  }
}
