import 'package:test/test.dart';

import 'package:proxy/utils/utils.dart';
import 'package:proxy/utils/const.dart' as type;
import 'package:proxy/sniff/sniffer.dart';

void main() {
  test('sniff TLS', () {
    expect(sniff([0x16, 0x03, 0x02, 0x01, 0x83, 0x01, 0x00, 0x01]),
        type.TrafficType.tls);
    expect(sniff([0x16, 0x03, 0x02, 0x02, 0x83, 0x01, 0x00, 0x01]),
        type.TrafficType.tls);
    expect(sniff([0x16, 0x03, 0x00, 0x02, 0x83, 0x01, 0x00, 0x01]),
        type.TrafficType.unknow);
    expect(sniff([0x16, 0x03, 0x01, 0x02, 0x83, 0x02, 0x00, 0x01]),
        type.TrafficType.unknow);
  });

  test('sniff http', () {
    expect(sniff([0, 1, 2, 3]), type.TrafficType.unknow);
    expect(sniff(buildHTTPProxyRequest('12')), type.TrafficType.http);
  });
}

mixin TrafficType {}
