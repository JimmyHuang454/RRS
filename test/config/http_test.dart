import 'package:test/test.dart';

import 'package:proxy/handler.dart';
import 'package:proxy/transport/client/tcp.dart';

void main() {
  test('buildInStream', () async {
    buildInStream('TCPServer_http', {'protocol': 'tcp'});

    var listen = '127.0.0.1';
    var port = 8081;
    var server = await buildInbounds('HTTPIn', {
      'protocol': 'http',
      'inStream': 'TCPServer_http',
      'routeTag': '1',
      'setting': {'address': listen, 'port': port}
    });


    buildRoute('1', {
      'rules': [
        {'outTag': 'freedom'}
      ]
    });

    var client = TCPClient(config: {'tag': 'TCPClient_http'});
    await client.connect(listen, port);

    client.add('GET http://uif02.xyz/test HTTP/1.1\r\nHost: uif02.xyz\r\n\r\n'
        .codeUnits);
    await Future.delayed(Duration(seconds: 2));
    client.listen(
      (event) {
        print(event);
      },
    );
  });
}
