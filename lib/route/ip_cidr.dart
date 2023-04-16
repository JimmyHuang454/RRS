class CIDRIPv4 {
  int len = 0;
  int prefix = 0;

  int parse(String rawIP) {
    if (!rawIP.contains('/')) {
      return 0;
    }

    var temp = rawIP.split('/');
    if (temp.length != 2) {
      return 0;
    }

    var tempPrefixStr = temp[0].split('.');
    len = int.parse(temp[1]);

    if (tempPrefixStr.length != 4 || len > 32 || len < 0) {
      return 0;
    }

    var res = 0;

    for (var i = 0; i < 4; ++i) {
      res |= int.parse(tempPrefixStr[i]) << (24 - (i * 8));
    }

    res &= int.parse('1' * len + '0' * (32 - len), radix: 2);

    return res;
  }

  bool init(String rawIP) {
    try {
      prefix = parse(rawIP);
    } catch (e) {
      return false;
    }

    if (prefix == 0) {
      return false;
    }
    return true;
  }

  bool matchByString(String inputRawIP) {
    var obj = CIDRIPv4();
    obj.init(inputRawIP);
    return match(obj);
  }

  bool match(CIDRIPv4 inputIP) {
    var minLen = inputIP.len > len ? len : inputIP.len;
    var minPrefix = int.parse('1' * minLen + '0' * (32 - minLen), radix: 2);
    return (inputIP.prefix & minPrefix) == (prefix & minPrefix);
  }

  bool include(String rawIPAddress) {
    return matchByString('$rawIPAddress/32');
  }
}
