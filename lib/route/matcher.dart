import 'package:proxy/obj_list.dart';
import 'package:proxy/route/ip_cidr.dart';
import 'package:proxy/route/mmdb.dart';

abstract class Pattern {
  String type = '';
  String pattern = '';

  Pattern({required this.type, required this.pattern});

  Future<bool> match(String inputPattern);
}

class RegexPattern extends Pattern {
  late RegExp regex;

  RegexPattern({required super.pattern}) : super(type: 'regex') {
    regex = RegExp(pattern);
  }

  @override
  Future<bool> match(String inputPattern) async {
    return regex.hasMatch(inputPattern);
  }
}

class FullPattern extends Pattern {
  FullPattern({required super.pattern}) : super(type: 'full');

  @override
  Future<bool> match(String inputPattern) async {
    return pattern == inputPattern;
  }
}

class MMDBPattern extends Pattern {
  late MMDB dbOBJ;

  MMDBPattern({required super.pattern, required dbName}) : super(type: 'mmdb') {
    if (!ipdbList.containsKey(dbName)) {
      throw "wrong ipdb name: $dbName.";
    }
    dbOBJ = ipdbList[dbName]!;
  }

  @override
  Future<bool> match(String inputPattern) async {
    try {
      await dbOBJ.load();
      var res = await dbOBJ.search(inputPattern);
      if (res != null && res['country']['iso_code'] == pattern) {
        return true;
      }
    } catch (_) {}
    return false;
  }
}

class SubstringPattern extends Pattern {
  SubstringPattern({required super.pattern}) : super(type: 'substring');

  @override
  Future<bool> match(String inputPattern) async {
    return inputPattern.contains(pattern);
  }
}

class IPCIDRPattern extends Pattern {
  late CIDRIPv4 cidriPv4;

  IPCIDRPattern({required super.pattern}) : super(type: 'CIDR') {
    cidriPv4 = CIDRIPv4();
    cidriPv4.init(pattern);
  }

  @override
  Future<bool> match(String inputPattern) async {
    return cidriPv4.matchByString(inputPattern);
  }
}
