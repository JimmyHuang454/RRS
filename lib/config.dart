import 'package:logging/logging.dart';
import 'package:proxy/utils/utils.dart';
import 'package:stack_trace/stack_trace.dart';

void applyLogConfig(Map<String, dynamic> config) {
  var debugLevelStr = getValue(config, 'log.level', 'info');
  devPrint(debugLevelStr);

  if (debugLevelStr == 'debug') {
    Logger.root.level = Level.FINEST;
    print('log level set to "debug" means print everything at length.');
  } else if (debugLevelStr == 'none') {
    Logger.root.level = Level.OFF;
    print('log level set to "none" means print nothing.');
  } else if (debugLevelStr == 'info') {
    Logger.root.level = Level.INFO;
    print('log level set to "info" means print info user need to know.');
  } else {
    throw 'UNKNOW log level';
  }

  Logger.root.onRecord.listen((record) async {
    print('${record.level.name}: ${record.message}');
    if (record.level == Level.FINEST) {
      print(Chain.current().toString());
    }
  });
}
