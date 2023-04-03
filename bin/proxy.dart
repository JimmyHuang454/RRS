import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:json5/json5.dart';
import 'package:logging/logging.dart';

import 'package:stack_trace/stack_trace.dart';

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

void main(List<String> argument) async {
  ////////////////
  //  argument  //
  ////////////////
  var argsParser = ArgParser();
  var root = getRunningDir();

  argsParser.addOption('config_path',
      abbr: 'c',
      defaultsTo: '$root/config.json',
      help: 'Path to your config. Default to use "config.json" in root dir.');

  argsParser.addOption('debug_level',
      defaultsTo: 'debug', allowed: ['debug', 'info', 'none']);

  argsParser.addOption('ipdb',
      defaultsTo: '$root/ip.mmdb', help: 'database for ip region.');

  var args = argsParser.parse(argument);

  ////////////
  //  init  //
  ////////////
  setLoggerLevel(args['debug_level']);

  // root
  logger.config('Running at: $root');

  // load config.
  var configPath = args['config_path'];
  logger.config('Using config at: $configPath');
  await loadConfig(configPath);

  ////////////
  //  main  //
  ////////////
  entry(config);
}
