class CIDR {
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
      res |= (int.parse(tempPrefixStr[i]) << (24 - i * 8));
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
    var obj = CIDR();
    var res = obj.parse(inputRawIP);
    if (res == 0) {
      return false;
    }

    return match(obj);
  }

  bool match(CIDR inputIP) {
    return true;
  }
}
