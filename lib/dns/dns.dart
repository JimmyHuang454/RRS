import 'dart:io';

import 'package:dcache/dcache.dart';
import 'package:dns_client/dns_client.dart';
import 'package:proxy/utils/utils.dart';

// such as 'udp://1.1.1.1:53', 'tcp://1.1.1.1:80'
abstract class DNS {
  Map<String, dynamic> config;
  String? dnsServerAddress;
  int? dnsServerPort;
  String type; // udp, tcp, doh

  int? ttl;
  bool? enabledCache;
  int? cacheSize;
  Cache? cache;

  DNS({required this.config, required this.type}) {
    enabledCache = getValue(config, 'cache.enable', false);
    dnsServerAddress = getValue(config, 'address', '');
    dnsServerPort = getValue(config, 'port', 443);
    ttl = getValue(config, 'ttl', 18000);
    type = getValue(config, 'type', 'doh');
    cacheSize = getValue(config, 'cache.size', 1000);

    if (dnsServerAddress == '') {
      throw Exception('required dnsServerAddress.');
    }

    if (enabledCache!) {
      cache = LruCache<String, String>(
        storage: InMemoryStorage<String, String>(cacheSize!),
      );
    }
  }

  Future<String> resolve(String domain);

  Future<String> resolveWithCache(String domain) async {
    if (domain == '') {
      return '';
    }

    if (enabledCache!) {
      var cachedRes = cache!.get(domain);
      if (cachedRes != null) {
        return cachedRes;
      }
    }

    var res = await resolve(domain);

    if (enabledCache!) {
      cache!.set(domain, res);
    }
    return res;
  }
}

class DoH extends DNS {
  DnsOverHttps? dnsOverHttps;
  DoH({required super.config}) : super(type: 'doh') {
    var timeout = getValue(config, 'timeout', 10);

    dnsOverHttps =
        DnsOverHttps(dnsServerAddress!, timeout: Duration(seconds: timeout));
  }

  @override
  Future<String> resolve(String domain) async {
    if (domain == '') {
      return '';
    }
    List<InternetAddress> record;

    try {
      record = await dnsOverHttps!.lookup(domain);
      if (record.isNotEmpty) {
        return record[0].address;
      }
    } catch (e) {
      return '';
    }
    return '';
  }
}
