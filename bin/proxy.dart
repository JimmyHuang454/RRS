import 'dart:async';
import 'dart:io';
import 'package:json5/json5.dart';

import 'package:proxy/handler.dart';
import 'package:proxy/utils/utils.dart';

void main(List<String> arguments) async {
  var configFile = File(
      'C:/Users/qwer/Desktop/vimrc/myproject/ECY/flutter/proxy2/proxy/config/basic.json');
  var config = await configFile.readAsString();
  var configJson = (JSON5.parse(config) as Map<String, dynamic>);

  runZonedGuarded(() {
    entry(configJson);
  }, (e, s) {
    devPrint(e);
  });
}
