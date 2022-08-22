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
}
