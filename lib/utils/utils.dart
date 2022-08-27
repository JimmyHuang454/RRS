import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  return ServerSocket.bind(address, 0).then((socket) {
    var port = socket.port;
    socket.close();
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

class Address {
  late InternetAddress internetAddress;

  late String rawString;
  String _type = '';

  Address(this.rawString) {
    try {
      internetAddress = InternetAddress(rawString);
    } catch (_) {
      _type = 'domain';
    }
  }

  Address.fromRawAddress(List<int> data, String rawType) {
    if (rawType == 'domain') {
      _type = 'domain';
      rawString = utf8.decode(data);
    } else {
      internetAddress =
          InternetAddress.fromRawAddress(Uint8List.fromList(data));
    }
  }

  String get address {
    return _type == 'domain' ? rawString : internetAddress.address;
  }

  String get host => _type == 'domain' ? rawString : internetAddress.host;

  bool get isLinkLocal =>
      _type == 'domain' ? false : internetAddress.isLoopback;

  bool get isLoopback => _type == 'domain' ? false : internetAddress.isLoopback;

  bool get isMulticast =>
      _type == 'domain' ? false : internetAddress.isMulticast;

  String get type {
    if (_type == 'domain') {
      return 'domain';
    }
    if (internetAddress.type == InternetAddressType.IPv4) {
      return 'ipv4';
    }
    return 'ipv6';
  }

  Uint8List get rawAddress {
    var res =
        (_type == 'domain' ? rawString.codeUnits : internetAddress.rawAddress);
    return Uint8List.fromList(res);
  }
}
