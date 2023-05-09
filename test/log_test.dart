import 'package:logging/logging.dart';
import 'package:proxy/config.dart';
import 'package:proxy/utils/utils.dart';
import 'package:test/test.dart';

void main() {
  test('log', () async {
    applyLogConfig({
      'log': {'level': 'none'}
    });
    expect(Logger.root.level, Level.OFF);
    logger.finest('2');

    applyLogConfig({
      'log': {'level': 'debug'}
    });
    expect(Logger.root.level, Level.FINEST);
    logger.finest('2');

    try {
      applyLogConfig({
        'log': {'level': 'abc'}
      });
    } catch (e) {
      e.toString().contains('level');
    }
  });
}
