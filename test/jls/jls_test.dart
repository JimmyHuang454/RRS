import 'dart:io';

import 'package:proxy/transport/jls/jls.dart';
import 'package:proxy/utils/utils.dart';

import 'package:test/test.dart';

void main() {
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

  test('clientHello', () async {
    var host = '127.0.0.1';
    var serverPort = await getUnusedPort(InternetAddress(host));
    var httpServer = await ServerSocket.bind(host, serverPort);
    httpServer.listen(
      (event) async {
        event.listen((data) {
        });
      },
    );

    var client = await Socket.connect(host, serverPort);
    await delay(1);
  });
}
