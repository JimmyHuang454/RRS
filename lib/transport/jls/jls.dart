import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/transport/jls/format.dart';
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

class JLS {
  List<int> data = [];

  List<int> iv = [];
  List<int> pwd = [];
  SecretKey? finalPWD;

  FakeRandom? clientFakeRandom;
  FakeRandom? serverFakeRandom;
  Handshake? local; // can be client or server.
  Handshake? remote; // opposite to local.

  FingerPrint fingerPrint;

  final aes = AesGcm.with256bits(nonceLength: 64);
  SecretKey? sharedSecretKey;
  SimplePublicKey? simplePublicKey; // remote pub key.
  SimpleKeyPair? keyPair; // local keyPair.
  final supportGroup = X25519(); // only x25519.

  int sendID = 0;
  int receiveID = 0;

  JLS(
      {required String pwdStr,
      required String ivStr,
      required this.fingerPrint}) {
    pwd = utf8.encode(pwdStr);
    iv = utf8.encode(ivStr);
  }

  Future<void> getSecretKey() async {
    // remote should be init first.
    // input other side pubKey then generate sharedSecretKey.
    simplePublicKey = SimplePublicKey(
        remote!.extensionList!.getKeyShare(remote!.isClient()),
        type: KeyPairType.x25519);

    sharedSecretKey = await supportGroup.sharedSecretKey(
      keyPair: keyPair!,
      remotePublicKey: simplePublicKey!,
    );
  }

  Future<void> buildFinalPWD() async {
    var res = pwd +
        await sharedSecretKey!.extractBytes() +
        clientFakeRandom!.n +
        serverFakeRandom!.n;
    res = sha256.convert(res).bytes;
    finalPWD = await aes.newSecretKeyFromBytes(res);
  }

  Future<void> setKeyShare() async {
    keyPair = await supportGroup.newKeyPair();
    var pubKey = await keyPair!.extractPublicKey();
    local!.extensionList!.setKeyShare(pubKey.bytes, local!.isClient());
  }

  Future<ApplicationData> send(List<int> data) async {
    var id = Uint8List(8)..buffer.asByteData().setUint64(0, sendID, Endian.big);

    var packetIV = sha512.convert(iv + id).bytes;
    var secretBox =
        await aes.encrypt(data, secretKey: finalPWD!, nonce: packetIV);
    var appData = secretBox.mac.bytes + secretBox.cipherText;
    // var appData = data + randomBytes(16);
    sendID += 1;
    return ApplicationData(data: appData);
  }

  Future<List<int>> receive(ApplicationData input) async {
    var id = Uint8List(8)
      ..buffer.asByteData().setUint64(0, receiveID, Endian.big);
    var iv2 = sha512.convert(iv + id).bytes;
    var cipherText = input.data.sublist(16);
    var mac = Mac(input.data.sublist(0, 16));
    var secretBox = SecretBox(cipherText, nonce: iv2, mac: mac);
    List<int> res = [];

    try {
      res = await aes.decrypt(secretBox, secretKey: finalPWD!);
      // res = cipherText;
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

class JLSClient extends JLS {
  List<int>? servername;
  JLSClient(
      {required super.pwdStr,
      required super.ivStr,
      required super.fingerPrint,
      this.servername});

  @override
  Future<bool> check({required Handshake inputRemote}) async {
    // call after build.
    remote = inputRemote;

    var random = inputRemote.random!;
    inputRemote.random = zeroList();
    await getSecretKey();

    // iv == iv + clientHello(Not 0 random) + serverHello(0 random)
    var pwd2 = pwd + await sharedSecretKey!.extractBytes();
    var iv2 = iv + data + inputRemote.build();
    serverFakeRandom = FakeRandom(pwd: pwd2, iv: iv2);
    inputRemote.random = random; // !! must restore.
    var isValid = await serverFakeRandom!.parse(rawFakeRandom: random);
    await buildFinalPWD();
    return isValid;
  }

  @override
  Future<List<int>> build() async {
    local = fingerPrint.buildClientHello();
    setServerName();
    local!.random = zeroList();
    local!.sessionID = randomBytes(32);
    await setKeyShare();

    data = local!.build();

    // iv == iv + clientHello(0 random).
    var pwd2 = pwd;
    var iv2 = iv + data;
    clientFakeRandom = FakeRandom(pwd: pwd2, iv: iv2);
    local!.random = await clientFakeRandom!.build();
    data = local!.build();
    return data;
  }

  void setServerName() {
    if (servername != null) {
      local!.extensionList!.setServerName(servername!);
    }
  }
}

class JLSServer extends JLS {
  JLSServer(
      {required super.pwdStr,
      required super.ivStr,
      required super.fingerPrint});

  @override
  Future<bool> check({required Handshake inputRemote}) async {
    remote = inputRemote;
    var random = inputRemote.random!;

    inputRemote.random = zeroList();
    var pwd2 = pwd;
    var iv2 = iv + inputRemote.build();
    clientFakeRandom = FakeRandom(pwd: pwd2, iv: iv2);
    inputRemote.random = random; // !! must restore.

    var isValid = await clientFakeRandom!.parse(rawFakeRandom: random);
    return isValid;
  }

  @override
  Future<List<int>> build() async {
    local = fingerPrint.buildServerHello();
    local!.random = zeroList();
    local!.sessionID = remote!.sessionID;
    await setKeyShare();
    await getSecretKey();
    data = local!.build();

    // iv == iv + clientHello(Not 0 random) + serverHello(0 random)
    var pwd2 = pwd + await sharedSecretKey!.extractBytes();
    var iv2 = iv + remote!.build() + data;
    serverFakeRandom = FakeRandom(pwd: pwd2, iv: iv2);
    local!.random = await serverFakeRandom!.build();
    data = local!.build();
    await buildFinalPWD();
    return data;
  }
}

class JLSHandler {
  JLS jls;
  RRSSocket client;

  Duration jlsTimeout;
  String fallbackWebsite;

  List<int> content = [];
  bool isValid = false;
  bool isCheck = false;
  bool isReceiveChangeSpec = false;
  bool isSendChangeSpec = false;
  Completer<dynamic> checkRes = Completer<dynamic>();

  JLSHandler(
      {required this.jls,
      required this.client,
      this.jlsTimeout = const Duration(seconds: 10),
      this.fallbackWebsite = 'apple.com'});

  Future<bool> secure() async {
    return false;
  }

  List<int> waitRecord() {
    if (content.length < 5) {
      return [];
    }
    ByteData byteData =
        ByteData.sublistView(Uint8List.fromList(content.sublist(3, 5)));
    var len = byteData.getUint16(0, Endian.big);
    if (content.length - 5 < len) {
      return [];
    }
    var res = content.sublist(0, 5 + len);
    content = content.sublist(5 + len);
    if (len == 0) {
      return [];
    }
    return res;
  }

  Future<void> forward() async {
    var tcp = TCPClient(config: {});
    var fallback = await tcp.connect(fallbackWebsite, 443);

    client.listen((data) async {
      fallback.add(data);
    }, onDone: () async {
      fallback.close();
    }, onError: (e, s) async {
      fallback.close();
    });

    fallback.listen((data) async {
      client.add(data);
    }, onDone: () async {
      client.close();
    }, onError: (e, s) async {
      client.close();
    });
    fallback.add(content);
  }

  List<int> buildRandomCert({int len = 32}) {
    return ApplicationData(data: randomBytes(len)).build();
  }
}
