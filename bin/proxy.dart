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

void main(List<String> argument) async {
  var argsParser = ArgParser();
  var root = getRunningDir();

  logger.i('Running at: $root');

  argsParser.addOption('config_path',
      abbr: 'c',
      defaultsTo: '$root/config.json',
      help: 'Path to your config. Default to use "config.json" in root dir.');

  argsParser.addOption('debug_level',
      defaultsTo: 'info', allowed: ['debug', 'info', 'none']);

  var args = argsParser.parse(argument);

  await loadConfig(args['config_path']);

  String debugLevel = args['debug_level'];
  if (debugLevel == 'debug') {
    Logger.level = Level.debug;
  } else if (debugLevel == 'none') {
    Logger.level = Level.nothing;
  } else if (debugLevel == 'info') {
    Logger.level = Level.info;
  }

  entry(config);
}
