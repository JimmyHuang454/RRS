import 'package:proxy/handler.dart';
import 'package:proxy/obj_list.dart';
import 'package:test/test.dart';

void main() {
  test('buildInStream', () {
    var res = buildOutStream('TCPClient', {'protocol': 'tcp'});
    expect(res.tag, 'TCPClient');
    expect(res.config, {'protocol': 'tcp', 'tag': 'TCPClient'});
    expect(res.useTLS, false);
    expect(res.allowInsecure, false);
    expect(res.useSystemRoot, true);
    expect(res.timeout!.inSeconds, 100);

    expect(outStreamList.containsKey('TCPClient'.toLowerCase()), true);
    expect(outStreamList.containsKey('tCPClient'.toLowerCase()), false);
  });
}
