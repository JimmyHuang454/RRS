import 'package:cryptography/helpers.dart';
import 'package:proxy/handler.dart';
import 'package:proxy/obj_list.dart';
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
    var jlsClient =
        JLSClient(pwdStr: '123', ivStr: '456', fingerPrint: defaultFingerPrint);

    await jlsClient.build();
    expect(jlsClient.local!.random, jlsClient.clientFakeRandom!.fakeRandom);

    var parsedClient = ClientHello.parse(rawData: jlsClient.data);
    expect(parsedClient.build(), jlsClient.data);
  });

  test('serverHello', () async {
    var jlsClient =
        JLSClient(pwdStr: '123', ivStr: '456', fingerPrint: defaultFingerPrint);
    await jlsClient.build();
    var parsedClient = ClientHello.parse(rawData: jlsClient.data);
    var clientRandom = parsedClient.random;

    var jlsServer =
        JLSServer(pwdStr: '123', ivStr: '456', fingerPrint: defaultFingerPrint);
    expect(await jlsServer.check(inputRemote: parsedClient), true);

    // test random must be restored.
    expect(jlsServer.remote!.random, clientRandom);

    jlsServer =
        JLSServer(pwdStr: '23', ivStr: '456', fingerPrint: defaultFingerPrint);
    expect(await jlsServer.check(inputRemote: parsedClient), false);

    jlsServer =
        JLSServer(pwdStr: '123', ivStr: '56', fingerPrint: defaultFingerPrint);
    expect(await jlsServer.check(inputRemote: parsedClient), false);

    // can not change clientHello
    parsedClient.sessionID = randomBytes(32);
    jlsServer =
        JLSServer(pwdStr: '123', ivStr: '456', fingerPrint: defaultFingerPrint);
    expect(await jlsServer.check(inputRemote: parsedClient), false);
  });

  test('clientHello', () async {
    var jlsClient =
        JLSClient(pwdStr: '123', ivStr: '456', fingerPrint: defaultFingerPrint);
    var jlsServer =
        JLSServer(pwdStr: '123', ivStr: '456', fingerPrint: defaultFingerPrint);

    await jlsClient.build();

    // server received then parse it.
    var parsedClient = ClientHello.parse(rawData: jlsClient.data);

    // and check it.
    jlsServer.check(inputRemote: parsedClient);
    expect(await jlsServer.check(inputRemote: parsedClient), true);

    await jlsServer.build();
    // client received then parse it.
    var parsedServer = ServerHello.parse(rawData: jlsServer.data);
    // and check it.
    expect(await jlsClient.check(inputRemote: parsedServer), true);

    var sharedKey = parsedServer.extensionList!.getKeyShare(false);
    parsedServer.extensionList!.setKeyShare(randomBytes(32), false);
    expect(await jlsClient.check(inputRemote: parsedServer), false);

    parsedServer.extensionList!.setKeyShare(sharedKey, false);
    expect(await jlsClient.check(inputRemote: parsedServer), true);

    parsedServer.sessionID = zeroList();
    expect(await jlsClient.check(inputRemote: parsedServer), false);
  });
}
