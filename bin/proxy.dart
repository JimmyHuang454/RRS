import 'package:args/args.dart';

import 'package:proxy/handler.dart';
import 'package:proxy/utils/utils.dart';

// return config path.
String loadArgv(List<String> argument) {
  var argsParser = ArgParser();
  var root = getRunningDir();

  argsParser.addOption('config',
      abbr: 'c',
      defaultsTo: '$root/config.json',
      help: 'Path to your config. Default to use "config.json" in root dir.');

  var args = argsParser.parse(argument);
  var configPath = args['config'];

  print('Running at: $root');
  print('Using config at: $configPath');
  return configPath;
}

void main(List<String> argument) async {
  // load config, parse it and run main process.
  var configFilePath = loadArgv(argument);
  entry(await readConfigWithJson5(configFilePath));
}
