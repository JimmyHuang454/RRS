import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:json5/json5.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';

import 'package:proxy/utils/const.dart';

final logger = Logger('RRS');

dynamic getValue(Map<String, dynamic> map, String key, dynamic defaultValue) {
  var temp = key.split('.');
  dynamic deep = map;
  for (var i = 0, len = temp.length; i < len; ++i) {
    try {
      if (deep.containsKey(temp[i])) {
        deep = deep[temp[i]];
        continue;
      }
    } catch (_) {}
    return defaultValue;
  }
  return deep;
}

String getRunningDir() {
  final pathToScript = Platform.script.toFilePath();
  final pathToDirectory = dirname(pathToScript);
  return pathToDirectory;
}

Future<void> delay(int seconds) async {
  await Future.delayed(Duration(seconds: seconds));
}

Future<Map<String, dynamic>> readConfigWithJson5(String filePath) async {
  var f = File(filePath);
  var config = JSON5.parse(await f.readAsString()) as Map<String, dynamic>;
  return config;
}

int indexOfElements(List<int> content, List<int> pattern, [int start = 0]) {
  if (start == -1) {
    return -1;
  }
  var i = start;
  for (; i < content.length && pattern.isNotEmpty; ++i) {
    var j = 0;
    var k = i + j;
    for (; j < pattern.length && k < content.length; ++j) {
      if (content[k] != pattern[j]) {
        break;
      }
      k += 1;
    }
    if (j == pattern.length) {
      return i;
    }
  }
  return -1;
}

void devPrint(msg) {
  print(msg);
}

String toMetric(int nr, [int round = 0]) {
  var temp = nr.toString();
  var len = temp.length;
  var i = 0;
  for (; i < temp.length; ++i) {
    if (len - 3 > 0) {
      len -= 3;
    } else {
      break;
    }
  }
  if (i == 0) {
    return temp;
  }
  var j = temp.length - (i * 3);
  var k = temp.substring(0, j);
  if (round != 0) {
    k += '.${temp.substring(j, j + round)}';
  }
  final map = {1: 'K', 2: 'M', 3: 'G', 4: 'T', 5: 'P'};
  return '$k${map[i]}';
}

Future<int> getUnusedPort(InternetAddress address) {
  return ServerSocket.bind(address, 0).then((socket) async {
    var port = socket.port;
    await socket.close();
    return port;
  });
}

void translateTo(List<int> input) {
  var start = 0;
  var pos = -1;
  while (true) {
    pos = input.indexOf(200, start);
    if (pos == -1) {
      break;
    }
    start = pos + 2;
    input.insert(pos, 200);
  }
}

void translateFrom(List<int> input) {
  var start = 0;
  var pos = -1;
  while (true) {
    pos = input.indexOf(200, start);
    if (pos == -1) {
      break;
    }
    start = pos + 1;
    input.removeAt(pos);
  }
}

List<int> findEnd(List<int> input) {
  var meet = false;
  var i = 0;
  for (var len = input.length; i < len; ++i) {
    if (input[i] == 200) {
      if (meet) {
        meet = false;
      } else {
        meet = true;
      }
    } else if (meet) {
      return input.sublist(0, i - 1);
    }
  }

  return input.sublist(0, i);
}

List<int> buildHTTPProxyRequest(String domain) {
  var res = 'GET http://$domain HTTP/1.1\r\nHost: $domain\r\n\r\n';
  return res.codeUnits;
}

class Address {
  late InternetAddress internetAddress;

  String rawString = '';
  AddressType? _type;

  Address(this.rawString) {
    try {
      internetAddress = InternetAddress(rawString);
      if (internetAddress.type == InternetAddressType.IPv4) {
        _type = AddressType.ipv4;
      } else {
        _type = AddressType.ipv6;
      }
    } catch (_) {
      if (rawString.contains(':')) {
        throw 'uri is not supported.';
      }
      _type = AddressType.domain;
    }
  }

  Address.fromRawAddress(List<int> data, AddressType addressType) {
    if (addressType == AddressType.domain) {
      _type = AddressType.domain;
      rawString = utf8.decode(data);
    } else {
      internetAddress =
          InternetAddress.fromRawAddress(Uint8List.fromList(data));
      if (internetAddress.type == InternetAddressType.IPv4) {
        _type = AddressType.ipv4;
      } else {
        _type = AddressType.ipv6;
      }
    }
  }

  bool isDomain() {
    if (_type == null) {
      return false;
    }
    return _type == AddressType.domain;
  }

  String get address {
    return isDomain() ? rawString : internetAddress.address;
  }

  bool get isLinkLocal => isDomain() ? false : internetAddress.isLoopback;

  bool get isLoopback => isDomain() ? false : internetAddress.isLoopback;

  bool get isMulticast => isDomain() ? false : internetAddress.isMulticast;

  AddressType get type {
    if (isDomain()) {
      return AddressType.domain;
    }
    if (internetAddress.type == InternetAddressType.IPv4) {
      return AddressType.ipv4;
    }
    return AddressType.ipv6;
  }

  Uint8List get rawAddress {
    var res = (isDomain() ? rawString.codeUnits : internetAddress.rawAddress);
    return Uint8List.fromList(res);
  }
}

String generateRandomString(int len) {
  final result = String.fromCharCodes(
      List.generate(len, (index) => Random().nextInt(33) + 89));
  return result;
}
