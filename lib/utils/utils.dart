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

int indexOfElements(List<int> old, List<int> n, [int start = 0]) {
  var i = start;
  for (; i < old.length && i + 3 < old.length; ++i) {
    var j = 0;
    for (; j < n.length; ++j) {
      if (old[i + j] != n[j]) {
        break;
      }
    }
    if (j == n.length) {
      return i;
    }
  }
  return -1;
}

void devPrint(msg) {
  print(msg);
}

Future<int> getUnusedPort(InternetAddress address) {
  return ServerSocket.bind(address, 0).then((socket) {
    var port = socket.port;
    socket.close();
    return port;
  });
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
      internetAddress = InternetAddress.fromRawAddress(Uint8List.fromList(data));
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
