import 'package:proxy/handler.dart';
import 'package:test/test.dart';

void main() {
  test('buildInStream', () {
    var res = buildInStream('TCPServer', {'protocol': 'tcp'});
    expect(res.transportServer1.tag, 'TCPServer');
    expect(res.transportServer1.config, {'protocol': 'tcp', 'tag': 'TCPServer'});
    expect(res.transportServer1.useTLS, false);
    expect(res.transportServer1.requireClientCertificate, true);
    expect(res.transportServer1.supportedProtocols, ['']);
  });
}
