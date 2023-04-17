import 'package:proxy/utils/utils.dart';
import 'package:test/test.dart';

void main() {
  test('temp test.', () {
    Map<List<int>, int> map = {};
    var d = [0];
    map[d] = 1;
    map[d] = 2;

    devPrint(map.containsKey(d));
    devPrint(map);
  });
}
