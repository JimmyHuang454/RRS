import 'dart:io';

import 'package:test/test.dart';
import 'package:proxy/utils/utils.dart';

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
    expect(toMetric(1000), '1K');
    expect(toMetric(2001), '2K');
    expect(toMetric(22001), '22K');
    expect(toMetric(122001), '122K');
    expect(toMetric(3122001), '3M');
    expect(toMetric(33122001), '33M');
    expect(toMetric(333122001), '333M');
    expect(toMetric(4333122001), '4G');
    expect(toMetric(14333122001), '14G');
    expect(toMetric(5444333122001), '5T');
    expect(toMetric(555444333122001), '555T');
  });

  test('compress', () {
  });
}
