import 'dart:io';

import 'package:proxy/utils/utils.dart';
import 'package:test/test.dart';

void main() {
  test('clientHello', () async {
    var host = '127.0.0.1';
    var serverPort = await getUnusedPort(InternetAddress(host));
    var httpServer = await ServerSocket.bind(host, serverPort);
    httpServer.listen(
      (event) async {
        event.listen((data) {});
      },
    );

    var client = await Socket.connect(host, serverPort);
  });
}
