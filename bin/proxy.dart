import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:json5/json5.dart';
import 'package:logging/logging.dart';

import 'package:stack_trace/stack_trace.dart';

import 'package:proxy/handler.dart';
import 'package:proxy/utils/utils.dart';

void setLoggerLevel(String debugLevelStr) {
  if (debugLevelStr == 'debug') {
    Logger.root.level = Level.FINEST;
  } else if (debugLevelStr == 'none') {
    Logger.root.level = Level.OFF;
  } else if (debugLevelStr == 'info') {
    Logger.root.level = Level.INFO;
  } else {
    Logger.root.level = Level.CONFIG;
  }

  Logger.root.onRecord.listen((record) async {
    print('${record.level.name}: ${record.message}');
    if (record.level == Level.FINEST) {
      print(Chain.current().toString());
    }
  });
}

// return config path.
String loadArgv(List<String> argument) {
  var argsParser = ArgParser();
  var root = getRunningDir();

  argsParser.addOption('config_path',
      abbr: 'c',
      defaultsTo: '$root/config.json',
      help: 'Path to your config. Default to use "config.json" in root dir.');

  argsParser.addOption('debug_level',
      defaultsTo: 'debug', allowed: ['debug', 'info', 'none']);

  var args = argsParser.parse(argument);
  var configPath = args['config_path'];

  setLoggerLevel(args['debug_level']);

  logger.config('Running at: $root');
  logger.config('Using config at: $configPath');
  return configPath;
}

void main(List<String> argument) async {
  // load config, parse it and run main process.
  var configFilePath = loadArgv(argument);
  entry(await readConfigWithJson5(configFilePath));
}
