import 'package:test/test.dart';

import 'package:proxy/sniff/sniffer.dart';

void main() {
  test('sniff TLS', () {
    var res = sniff([]); // TODO
    // expect(res.isTLS, false);

    // res = sniff([0x16, 0x03, 0x03, 0x01, 0x83, 0x01, 0x00, 0x01]);
    // expect(res.isTLS, true);
    // expect(res.tlsVersion, 'TLS1.3');
    // expect(res.tlsLayerType, 'HandShake');
    // expect(res.layerLength, 387);

    // res = sniff([16, 0x03, 0x03, 0x01, 0x83, 0x01, 0x00, 0x01]);
    // expect(res.isTLS, false);
  });
}
