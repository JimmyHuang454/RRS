import 'package:proxy/handler.dart';
import 'package:test/test.dart';

void main() {
  test('buildInStream', () async {
    buildInStream('TCPServer_http', {'protocol': 'tcp'});

    var listen = '127.0.0.1';
    var port = 8080;
    var res = await buildInbounds('HTTPIn', {
      'protocol': 'http',
      'inStream': 'TCPServer_http',
      'routeTag': '1',
      'setting': {'address': listen, 'port': port}
    });
    res.bind2();
  });
}
