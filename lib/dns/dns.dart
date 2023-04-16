import 'dart:io';

import 'package:dcache/dcache.dart';
import 'package:dns_client/dns_client.dart';
import 'package:proxy/utils/utils.dart';

abstract class DNS {
  Map<String, dynamic> config;

  // such as 'udp://1.1.1.1:53', 'tcp://1.1.1.1:80'
  String? dnsServerAddress;
  int? dnsServerPort;
  String type; // udp, tcp, doh

  int? ttl;
  bool? enabledCache;
  int? cacheSize;
  Cache? cache;

  DNS({required this.config, required this.type}) {
    enabledCache = getValue(config, 'enabledCache', false);
    dnsServerAddress = getValue(config, 'address', '');
    dnsServerPort = getValue(config, 'port', 443);
    ttl = getValue(config, 'ttl', 18000);
    type = getValue(config, 'type', 'doh');
    cacheSize = getValue(config, 'cacheSize', 500);

    if (dnsServerAddress == '') {
      throw Exception('required dnsServerAddress.');
    }

    if (enabledCache!) {
      cache = LruCache<String, bool>(
        storage: InMemoryStorage<String, bool>(cacheSize!),
      );
    }
  }

  Future<String> resolve(String domain);

  Future<String> resolve2(String domain) async {
    String res;

    if (domain == '') {
      return '';
    }

    if (enabledCache!) {
      var cachedRes = cache!.get(domain);
      if (cachedRes != null) {
        return cachedRes;
      }
    }

    res = await resolve(domain);

    if (enabledCache!) {
      cache!.set(domain, res);
    }
    return res;
  }
}

class DoH extends DNS {
  DnsOverHttps? dnsOverHttps;
  DoH({required super.config}) : super(type: 'doh') {
    // dnsServerAddress = 'https://doh.pub/dns-query'
    dnsOverHttps = DnsOverHttps(dnsServerAddress!);
  }

  @override
  Future<String> resolve(String domain) async {
    if (domain == '') {
      return '';
    }
    List<InternetAddress> record;
    record = await dnsOverHttps!.lookup(domain);

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
