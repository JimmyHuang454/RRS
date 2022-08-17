import 'dart:convert';
import 'dart:io';

import 'package:proxy/handler.dart';
import 'package:proxy/obj_list.dart';


void main(List<String> arguments) async {
  var configFile = File(
      'C:/Users/qwer/Desktop/vimrc/myproject/ECY/flutter/proxy2/proxy/config/basic.json');
  var config = await configFile.readAsString();
  var configJson = (jsonDecode(config) as Map<String, dynamic>);

  if (configJson.containsKey('inStream')) {
    var inStream = (configJson['inStream'] as Map<String, dynamic>);
    inStream.forEach(
      (key, value) {
        inStreamList[key] = buildInStream(key, value);
      },
    );
  }

  if (configJson.containsKey('outStream')) {
    var outStream = (configJson['outStream'] as Map<String, dynamic>);
    outStream.forEach(
      (key, value) {
        outStreamList[key] = buildOutStream(key, value);
      },
    );
  }

  if (configJson.containsKey('inbounds')) {
    var inbounds = (configJson['inbounds'] as Map<String, dynamic>);
    inbounds.forEach(
      (key, value) async {
        inboundsList[key] = await buildInbounds(key, value);
      },
    );
  }

  print(inStreamList);
  print(outStreamList);
}
