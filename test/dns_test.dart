import 'package:proxy/handler.dart';
import 'package:proxy/obj_list.dart';
import 'package:test/test.dart';

void main() {
  test('dns', () async {
    entry({
      'dns': {
        'cache': {
          'type': 'doh',
          'address': 'https://cloudflare-dns.com/dns-query',
          'cache': {'enable': true}
        }
      }
    });
    var doh = dnsList['cloudflare']!;

    expect(doh.type, 'doh');
    expect(doh.enabledCache, false);
    var res = await doh.resolve2('');
    expect(res, '');
    res = await doh.resolve2('baidu.com');
    expect(res != '', true);

    var cache = dnsList['cache']!;
    expect(cache.enabledCache, true);
    res = await cache.resolve2('');
    expect(res, '');
    var temp = await cache.resolve2('baidu.com');
    expect(temp != '', true);
    expect(cache.cache!.length, 1);

    res = await cache.resolve2('baidu.com');
    expect(temp, res);

    var isError = false;
    try {
      entry({
        'dns': {
          'cache2': {
            'type': 'doh',
            'address': '',
            'cache': {'enable': true}
          }
        }
      });
    } catch (_) {
      isError = true;
    }

    expect(isError, true);
  });
}
