import 'package:dcache/dcache.dart';
import 'package:proxy/obj_list.dart';
import 'package:proxy/route/ip_cidr.dart';
import 'package:proxy/route/mmdb.dart';
import 'package:proxy/utils/utils.dart';

abstract class Pattern {
  String type = '';
  String pattern = '';
  bool enabledCache;
  int cacheSize;
  Cache? cache;

  Pattern(
      {required this.type,
      required this.pattern,
      this.enabledCache = false,
      this.cacheSize = 0}) {
    setCache(enabledCache, cacheSize);
  }

  void setCache(bool enable, int size) {
    enabledCache = enable;
    cacheSize = cacheSize;

    if (enabledCache) {
      cache = LruCache<String, bool>(
        storage: InMemoryStorage<String, bool>(cacheSize),
      );
    }
  }

  Future<bool> match(String inputPattern);

  Future<bool> match2(String inputPattern) async {
    bool res;
    if (enabledCache && inputPattern != '') {
      var cachedRes = cache!.get(inputPattern);
      if (cachedRes != null) {
        return cachedRes;
      }
    }

    res = await match(inputPattern);

    if (enabledCache && inputPattern != '') {
      cache!.set(inputPattern, res);
    }
    return res;
  }
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

  IPCIDRPattern({required super.pattern}) : super(type: 'cidr') {
    cidriPv4 = CIDRIPv4();
    cidriPv4.init(pattern);
  }

  @override
  Future<bool> match(String inputPattern) async {
    return cidriPv4.include(inputPattern);
  }
}
