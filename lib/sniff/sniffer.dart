import 'dart:typed_data';

class TrafficType {
  bool isTLS = false;
  String tlsVersion = '';
  String tlsLayerType = '';

  int layerLength = 0;
}

TrafficType sniff(List<int> data) {
  var res = TrafficType();
  if (data.length < 5) {
    return res;
  }

  if (data[1] == 0x0303) {
    res.isTLS = true;

    if (data[0] == 0x16) {
      res.tlsLayerType = 'HandShake';
    } else {
      // TODO: more layer type
    }

    var byteList = Uint8List.fromList(data.sublist(3, 5));
    var byteData = ByteData.sublistView(byteList);
    res.layerLength = byteData.getUint16(0, Endian.big);
  }

  return res;
}
