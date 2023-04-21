import 'package:proxy/handler.dart';
import 'package:proxy/obj_list.dart';
import 'package:test/test.dart';

void main() {
  test('dns', () async {
    entry({
      'dns': {
        'cache': {
          'type': 'doh',
          'address': 'https://doh.pub/dns-query',
          'cache': {'enable': true}
        }
      }
    });
    var doh = dnsList['txDOH']!;

    expect(doh.type, 'doh');
    expect(doh.enabledCache, false);
    var res = await doh.resolveWithCache('');
    expect(res, '');
    res = await doh.resolveWithCache('baidu.com');
    expect(res != '', true);

    var cache = dnsList['cache']!;
    expect(cache.enabledCache, true);
    res = await cache.resolveWithCache('');
    expect(res, '');
    var res2 = await cache.resolveWithCache('baidu.com');
    expect(res2 != '', true);
    expect(cache.cache!.length, 1);
    expect(cache.cache!.get('baidu.com'), res2);

    res = await cache.resolveWithCache('baidu.com');
    expect(res, res2);
  });

  test('dns missing address.', () {
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
