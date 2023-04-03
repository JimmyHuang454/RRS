import 'package:quiver/collection.dart';
import 'package:test/test.dart';
import 'package:proxy/utils/utils.dart';

import 'package:dcache/dcache.dart';

void main() {
  test('indexOfElements', () {
    var res = [1, 2, 3];
    expect(indexOfElements(res, [1]), 0);
    expect(indexOfElements(res, [2]), 1);
    expect(indexOfElements(res, [3]), 2);
    expect(indexOfElements(res, [4]), -1);
    expect(indexOfElements(res, [1, 2]), 0);
    expect(indexOfElements(res, [2, 3]), 1);
    expect(indexOfElements(res, [3, 4]), -1);
    expect(indexOfElements(res, [1, 2, 3]), 0);
    expect(indexOfElements(res, [1, 2, 3, 3]), -1);
    expect(indexOfElements(res, [2, 3]), 1);
    expect(indexOfElements(res, [2, 3, 1]), -1);
    expect(indexOfElements(res, [1], 1), -1);
    expect(indexOfElements(res, [2], 1), 1);
    expect(indexOfElements(res, [3], 1), 2);
    expect(indexOfElements(res, [3], 2), 2);
    expect(indexOfElements(res, [3], 3), -1);
    expect(indexOfElements(res, [3], -1), -1);
    expect(indexOfElements(res, [3], 0), 2);
    expect(indexOfElements(res, [1, 2], 1), -1);
    expect(indexOfElements(res, [1, 2], 0), 0);

    res = [1, 1, 1, 2, 2];
    expect(indexOfElements(res, [1]), 0);
    expect(indexOfElements(res, [1, 1]), 0);
    expect(indexOfElements(res, [1, 1, 1]), 0);
    expect(indexOfElements(res, [1, 1], 1), 1);
    expect(indexOfElements(res, [1, 1, 1], 1), -1);
    expect(indexOfElements(res, [2, 2], 1), 3);
    expect(indexOfElements(res, [2, 2, 2], 1), -1);
    expect(indexOfElements(res, [1, 1], 2), -1);
  });

  test('toMetric', () {
    expect(toMetric(100), '100');
    expect(toMetric(100, 1), '100');
    expect(toMetric(1000), '1K');
    expect(toMetric(1000, 1), '1.0K');
    expect(toMetric(1400, 1), '1.4K');
    expect(toMetric(1400, 2), '1.40K');
    expect(toMetric(2001), '2K');
    expect(toMetric(22001), '22K');
    expect(toMetric(122001), '122K');
    expect(toMetric(3122001), '3M');
    expect(toMetric(33122001), '33M');
    expect(toMetric(333122001), '333M');
    expect(toMetric(4333122001), '4G');
    expect(toMetric(14333122001), '14G');
    expect(toMetric(14333122001, 2), '14.33G');
    expect(toMetric(14123122001, 2), '14.12G');
    expect(toMetric(5444333122001), '5T');
    expect(toMetric(555444333122001), '555T');
    expect(toMetric(555444333122001, 2), '555.44T');
  });

  test('translateTo', () {
    var input = [200, 2];
    translateTo(input);
    expect(listsEqual(input, [200, 200, 2]), true);

    input = [1, 2];
    translateTo(input);
    expect(listsEqual(input, [1, 2]), true);

    input = [200, 200, 200];
    translateTo(input);
    expect(listsEqual(input, [200, 200, 200, 200, 200, 200]), true);

    input = [10, 200, 200];
    translateTo(input);
    expect(listsEqual(input, [10, 200, 200, 200, 200]), true);

    input = [10, 201, 200];
    translateTo(input);
    expect(listsEqual(input, [10, 201, 200, 200]), true);

    input = [10, 200, 200];
    translateFrom(input);
    expect(listsEqual(input, [10, 200]), true);

    input = [200, 200, 200, 200, 200, 200];
    translateFrom(input);
    expect(listsEqual(input, [200, 200, 200]), true);

    input = [200, 200, 200, 200, 200, 200];
    translateTo(input);
    translateFrom(input);
    expect(listsEqual(input, input), true);

    input = [200, 200];
    input = findEnd(input);
    expect(listsEqual(input, [200, 200]), true);

    input = [200, 200, 200];
    input = findEnd(input);
    expect(listsEqual(input, [200, 200, 200]), true);

    input = [200, 200, 200, 200, 200, 0];
    input = findEnd(input);
    expect(listsEqual(input, [200, 200, 200, 200]), true);

    input = [1, 2, 200, 0];
    input = findEnd(input);
    expect(listsEqual(input, [1, 2]), true);
  });

  test('LRU', () {
    var c = LruCache<String, bool>(
      storage: InMemoryStorage<String, bool>(20),
    );
    c.set('1', true);

    expect(c.get('1'), true);
    expect(c.get('1'), 1);
    expect(c.get('2'), null);
  });
}
