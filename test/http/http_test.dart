import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';

import 'package:proxy/handler.dart';
import 'package:proxy/transport/client/tcp.dart';
import 'package:proxy/utils/utils.dart';

void main() {
  test('http', () async {
    var f = File('./test/http/http_freedom.json');
    var config = jsonDecode(await f.readAsString());
    var listen = '127.0.0.1';
    var port1 = await getUnusedPort(InternetAddress(listen));
    var port2 = await getUnusedPort(InternetAddress(listen));
    config['inbounds']['HTTPIn']['setting']['port'] = port1;
    config['inbounds']['HTTPIn_block']['setting']['port'] = port2;
    entry(config);
  });
}
