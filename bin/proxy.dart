import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:json5/json5.dart';
import 'package:logger/logger.dart';

import 'package:proxy/handler.dart';
import 'package:proxy/utils/utils.dart';

late Map<String, dynamic> config;

Future<void> loadConfig(path) async {
  var configFile = File(path);
  var temp = await configFile.readAsString();
  config = (JSON5.parse(temp) as Map<String, dynamic>);
}

void setLoggerLevel(String debugLevelStr) {
  if (debugLevelStr == 'debug') {
    Logger.level = Level.debug;
  } else if (debugLevelStr == 'none') {
    Logger.level = Level.nothing;
  } else if (debugLevelStr == 'info') {
    Logger.level = Level.info;
  } else {
    Logger.level = Level.verbose;
  }
}

void main(List<String> argument) async {
  var argsParser = ArgParser();
  var root = getRunningDir();

  argsParser.addOption('config_path',
      abbr: 'c',
      defaultsTo: '$root/config.json',
      help: 'Path to your config. Default to use "config.json" in root dir.');

  argsParser.addOption('debug_level',
      defaultsTo: 'debug', allowed: ['debug', 'info', 'none']);

  var args = argsParser.parse(argument);

  setLoggerLevel(args['debug_level']);

  logger.e('Running at: $root');
  await loadConfig(args['config_path']);

  entry(config);
}
