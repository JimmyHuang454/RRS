import 'dart:convert';
import 'dart:io';

import 'package:proxy/handler.dart';

void main(List<String> arguments) async {
  var configFile = File(
      'C:/Users/qwer/Desktop/vimrc/myproject/ECY/flutter/proxy2/proxy/config/basic.json');
  var config = await configFile.readAsString();
  var configJson = (jsonDecode(config) as Map<String, dynamic>);

  print('\r\n'.codeUnits);
  entry(configJson);
}
