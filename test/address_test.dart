import 'dart:io';

import 'package:maxminddb/maxminddb.dart';
import 'package:quiver/collection.dart';
import 'package:dns_client/dns_client.dart';
import 'package:test/test.dart';

import 'package:proxy/utils/utils.dart';

void main() {
  test('address', () {
    var res = Address('https://trojan-gfw.github.io/trojan/protocol');
    expect(res.address, 'https://trojan-gfw.github.io/trojan/protocol');
    expect(res.type, 'domain');

    res = Address('255.255.255.255');
    expect(res.address, '255.255.255.255');
    expect(res.type, 'ipv4');
    expect(listsEqual(res.rawAddress, [255, 255, 255, 255]), true);
  });

  test('geoip', () async {
    final database = await MaxMindDatabase.file(File(
        'C:/Users/qwer/Desktop/vimrc/myproject/ECY/flutter/proxy2/proxy/lib/Country.mmdb'));

    var res = await database.search('104.28.249.48');
    expect(res == null, true);

    var doh = DnsOverHttps('https://doh.pub/dns-query',
        timeout: Duration(seconds: 3));
    var record = await doh.lookup('www.baidu.com');

    for (var i = 0, len = record.length; i < len; ++i) {
      res = await database.search(record[i].address);
      expect(res == null, false);
      expect(res['country']['geoname_id'], 1814991);
    }
  });
}
