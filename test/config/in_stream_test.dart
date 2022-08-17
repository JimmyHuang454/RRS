import 'package:proxy/handler.dart';
import 'package:test/test.dart';

void main() {
  test('buildInStream', () {
    var res = buildInStream('TCPClient', {'protocol': 'tcp'})();
    expect(res.tag, 'TCPClient');
    expect(res.config, {'protocol': 'tcp', 'tag': 'TCPClient'});
    expect(res.useTLS, false);
    expect(res.requireClientCertificate, true);
    expect(res.supportedProtocols, ['']);
  });
}
