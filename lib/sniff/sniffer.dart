import 'dart:convert';

import 'package:proxy/utils/const.dart';

TrafficType sniff(List<int> data) {
  if (data.length < 6) {
    return TrafficType.unknow;
  }

  if (data[0] == 0x16 &&
      data[1] == 0x03 &&
      (data[2] == 0x01 || data[2] == 0x02) &&
      data[5] == 0x01) {
    return TrafficType.tls;
  }

  try {
    utf8.decode(data.sublist(0, 6));
    return TrafficType.http;
  } catch (_) {}

  return TrafficType.unknow;
}
