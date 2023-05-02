import 'package:proxy/handler.dart';
import 'package:test/test.dart';

void main() {
  test('buildInStream', () {
    var res = buildInStream('TCPServer', {'protocol': 'tcp'});
    expect(res.tag, 'TCPServer');
    expect(res.config, {'protocol': 'tcp', 'tag': 'TCPServer'});
    expect(res.useTLS, false);
    expect(res.requireClientCertificate, true);
    expect(res.supportedProtocols, ['']);
  });
}
