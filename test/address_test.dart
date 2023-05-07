import 'dart:convert';

import 'package:proxy/inbounds/base.dart';
import 'package:quiver/collection.dart';
import 'package:test/test.dart';

import 'package:proxy/utils/utils.dart';

void main() {
  test('uri use case.', () async {
    //{{{
    var temp = Uri.parse('http://127.0.0.1');
    expect(temp.host, '127.0.0.1');

    temp = Uri.parse('127.0.0.1');
    expect(temp.host, '');

    temp = Uri.parse('www.abc.com');
    expect(temp.host, '');

    temp = Uri.parse('abc.com');
    expect(temp.host, '');

    temp = Uri.parse('abc');
    expect(temp.host, '');
    expect(temp.scheme, '');

    temp = Uri.parse('fuck://abc');
    expect(temp.host, 'abc');
    expect(temp.scheme, 'fuck');

    temp = Uri.parse('fuck://abc.cn');
    expect(temp.host, 'abc.cn');
    expect(temp.scheme, 'fuck');
  }); //}}}

  test('address', () {
    var res = Address('255.255.255.255');
    expect(res.address, '255.255.255.255');
    expect(res.isDomain(), false);
    expect(res.type, AddressType.ipv4);
    expect(listsEqual(res.rawAddress, [255, 255, 255, 255]), true);

    res = Address('127.0.0.1');
    expect(res.type, AddressType.ipv4);
    expect(res.isDomain(), false);
    expect(res.isMulticast, false);
    expect(res.isLinkLocal, true);
    expect(res.isLoopback, true);
    expect(listsEqual(res.rawAddress, [127, 0, 0, 1]), true);

    res = Address('192.168.200.84');
    expect(res.type, AddressType.ipv4);
    expect(res.isDomain(), false);
    expect(res.isMulticast, false);
    expect(res.isLinkLocal, false);
    expect(res.isLoopback, false);

    try {
      res = Address('https://trojan-gfw.github.io/trojan/protocol');
    } catch (e) {
      expect(e.toString().contains('uri'), true);
    }

    var domain = 'www.abc.com';
    res = Address(domain);
    expect(res.isDomain(), true);
    expect(res.address, domain);
    expect(res.type, AddressType.domain);
    expect(listsEqual(res.rawAddress, utf8.encode(domain)), true);

    res = Address.fromRawAddress(utf8.encode(domain), AddressType.domain);
    expect(res.isDomain(), true);
    expect(res.type, AddressType.domain);
    expect(res.address, domain);
    expect(res.isMulticast, false);
    expect(res.isLinkLocal, false);
    expect(res.isLoopback, false);
    expect(res.rawAddress, utf8.encode(domain));
  });
}
