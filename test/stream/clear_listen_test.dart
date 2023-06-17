import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:test/test.dart';

import 'package:proxy/utils/utils.dart';

void main() async {
  var host = '127.0.0.1';
  var serverPort = await getUnusedPort(InternetAddress(host));
  var httpServer = await ServerSocket.bind(host, serverPort);

  httpServer.listen((event) async {
    event.listen((data) async {
      devPrint(data);
    });
  });

  test('stream use case.', () async {
    //{{{

    var client = await Socket.connect(host, serverPort);
    var fu = client.asBroadcastStream();

    var li = fu.listen((event) {
      devPrint(event);
    });
    await li.cancel();
    li = fu.listen((event) {
      devPrint(event);
    });
  }); //}}}
}
