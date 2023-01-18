import 'package:proxy/handler.dart';
import 'package:test/test.dart';

void main() {
  test('buildInStream', () {
    var res = buildInStream('TCPServer', {'protocol': 'tcp'});
    expect(res.transportServer.tag, 'TCPServer');
    expect(res.transportServer.config, {'protocol': 'tcp', 'tag': 'TCPServer'});
    expect(res.transportServer.useTLS, false);
    expect(res.transportServer.requireClientCertificate, true);
    expect(res.transportServer.supportedProtocols, ['']);
  });
}
