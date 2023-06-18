import 'package:cryptography/helpers.dart';
import 'package:proxy/handler.dart';
import 'package:proxy/obj_list.dart';
import 'package:proxy/transport/jls/format.dart';
import 'package:proxy/transport/jls/jls.dart';
import 'package:proxy/transport/jls/tls/base.dart';
import 'package:proxy/utils/utils.dart';

import 'package:test/test.dart';

void main() {
  entry({});
  var defaultFingerPrint = jlsFringerPrintList['default']!;

  test('fakeRandom', () async {
    var pwd = [1];
    var iv = [2];

    var f = FakeRandom(iv: iv, pwd: pwd);
    expect(f.iv.length, 64);
    expect(f.pwd.length, 32);
    await f.build();
    expect(f.n.length, 16);
    expect(f.fakeRandom.length, 32);

    var f2 = FakeRandom(iv: iv, pwd: pwd);
    expect(f2.n.length, 0);
    expect(f2.fakeRandom.length, 0);
    expect(await f2.parse(rawFakeRandom: f.fakeRandom), true);
    expect(f.iv, f2.iv);
    expect(f.pwd, f2.pwd);
    expect(f.n, f2.n);
    expect(f.fakeRandom, f2.fakeRandom);

    var f3 = FakeRandom(iv: [4], pwd: pwd);
    expect(await f3.parse(rawFakeRandom: f.fakeRandom), false);
    expect(f3.n, []);
    expect(f3.fakeRandom, []);

    var f4 = FakeRandom(iv: iv, pwd: [3]);
    expect(await f4.parse(rawFakeRandom: f.fakeRandom), false);
  });

  test('clientHello parse.', () async {
    var jlsHandShakeClient = JLSHandShakeClient(
        pwdStr: '123', ivStr: '456', local: defaultFingerPrint.clientHello);

    await jlsHandShakeClient.build();
    expect(jlsHandShakeClient.local!.random,
        jlsHandShakeClient.clientFakeRandom!.fakeRandom);

    var parsedClient = ClientHello.parse(rawData: jlsHandShakeClient.data);
    expect(parsedClient.build(), jlsHandShakeClient.data);
  });

  test('serverHello', () async {
    var jlsHandShakeClient = JLSHandShakeClient(
        pwdStr: '123', ivStr: '456', local: defaultFingerPrint.clientHello);
    await jlsHandShakeClient.build();
    var parsedClient = ClientHello.parse(rawData: jlsHandShakeClient.data);
    var clientRandom = parsedClient.random;

    var jlsHandShakeServer = JLSHandShakeServer(
        pwdStr: '123', ivStr: '456', local: defaultFingerPrint.serverHello);
    expect(await jlsHandShakeServer.check(inputRemote: parsedClient), true);

    // test random must be restored.
    expect(jlsHandShakeServer.remote!.random, clientRandom);

    jlsHandShakeServer = JLSHandShakeServer(
        pwdStr: '0123', ivStr: '456', local: defaultFingerPrint.serverHello);
    expect(await jlsHandShakeServer.check(inputRemote: parsedClient), false);

    jlsHandShakeServer = JLSHandShakeServer(
        pwdStr: '123', ivStr: '4567', local: defaultFingerPrint.serverHello);
    expect(await jlsHandShakeServer.check(inputRemote: parsedClient), false);

    // can not change clientHello
    parsedClient.sessionID = randomBytes(32);
    jlsHandShakeServer = JLSHandShakeServer(
        pwdStr: '123', ivStr: '456', local: defaultFingerPrint.serverHello);
    expect(await jlsHandShakeServer.check(inputRemote: parsedClient), false);
  });

  test('clientHello', () async {
    var jlsHandShakeClient = JLSHandShakeClient(
        pwdStr: '123', ivStr: '456', local: defaultFingerPrint.clientHello);
    var jlsHandShakeServer = JLSHandShakeServer(
        pwdStr: '123', ivStr: '456', local: defaultFingerPrint.serverHello);

    await jlsHandShakeClient.build();

    // server received then parse it.
    var parsedClient = ClientHello.parse(rawData: jlsHandShakeClient.data);

    // and check it.
    jlsHandShakeServer.check(inputRemote: parsedClient);
    expect(await jlsHandShakeServer.check(inputRemote: parsedClient), true);

    await jlsHandShakeServer.build();
    // client received then parse it.
    var parsedServer = ServerHello.parse(rawData: jlsHandShakeServer.data);
    // and check it.
    expect(await jlsHandShakeClient.check(inputRemote: parsedServer), true);

    var sharedKey = parsedServer.extensionList!.getKeyShare(false);
    parsedServer.extensionList!.setKeyShare(randomBytes(32), false);
    expect(await jlsHandShakeClient.check(inputRemote: parsedServer), false);

    parsedServer.extensionList!.setKeyShare(sharedKey, false);
    expect(await jlsHandShakeClient.check(inputRemote: parsedServer), true);

    parsedServer.sessionID = zeroList();
    expect(await jlsHandShakeClient.check(inputRemote: parsedServer), false);
  });
}
