import 'dart:io';
import 'package:maxminddb/maxminddb.dart';

Future<MaxMindDatabase> loadGeoIP() async {
  var f = File(
      'C:/Users/qwer/Desktop/vimrc/myproject/ECY/flutter/proxy2/proxy/lib/Country.mmdb');
  var geoip = await MaxMindDatabase.file(f);
  return geoip;
}
