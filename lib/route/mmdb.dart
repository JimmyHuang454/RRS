import 'dart:io';
import 'package:maxminddb/maxminddb.dart';

class MMDB {
  String name;
  String path;
  late MaxMindDatabase maxMindDatabase;

  MMDB(this.name, this.path);

  Future<MaxMindDatabase> load() async {
    var f = File(path);
    maxMindDatabase = await MaxMindDatabase.file(f);
    return maxMindDatabase;
  }

  Future<dynamic> search(String ip) async {
    return await maxMindDatabase.search(ip);
  }
}
