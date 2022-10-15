import 'dart:io';
import 'package:maxminddb/maxminddb.dart';

var ipdbPath = '';

Future<MaxMindDatabase> loadGeoIP() async {
  var f = File(ipdbPath);
  var geoip = await MaxMindDatabase.file(f);
  return geoip;
}
