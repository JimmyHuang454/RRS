import 'package:proxy/transport/jls/tls/base.dart';
import 'package:proxy/utils/utils.dart';
import 'package:test/test.dart';

void main() {
  List<int> randomB = [];
  for (var i = 0; i < 32; i++) {
    randomB.add(i);
  }
  var clientHello =
      "\x16\x03\x01\x00\xf3\x01\x00\x00\xef\x03\x03\x7c\xc4\x5b\x86\x56"
      "\xa1\x5e\xc4\x1d\xcc\xa9\xc2\x77\xe9\x5e\x38\x30\x8f\x6c\x4a\xba"
      "\xb8\xe8\xaa\xff\xca\x4b\x0f\xe6\x86\x6b\x15\x20\xdf\x16\x15\xec"
      "\x56\x96\x80\xb0\xd9\xb8\x22\xfa\x08\xea\x1c\xa0\x4e\x41\x14\x19"
      "\x20\xf2\x72\xe4\x10\xe2\x16\x7f\x2b\x31\x7a\x2c\x00\x24\x13\x03"
      "\x13\x01\x13\x02\xcc\xa9\xcc\xa8\xc0\x2b\xc0\x2f\xc0\x2c\xc0\x30"
      "\xc0\x09\xc0\x13\xc0\x0a\xc0\x14\x00\x9c\x00\x9d\x00\x2f\x00\x35"
      "\x00\x0a\x01\x00\x00\x82\x00\x00\x00\x0e\x00\x0c\x00\x00\x09\x75"
      "\x69\x66\x30\x33\x2e\x74\x6f\x70\x00\x17\x00\x00\xff\x01\x00\x01"
      "\x00\x00\x0a\x00\x08\x00\x06\x00\x1d\x00\x17\x00\x18\x00\x0b\x00"
      "\x02\x01\x00\x00\x23\x00\x00\x00\x0d\x00\x14\x00\x12\x04\x03\x08"
      "\x04\x04\x01\x05\x03\x08\x05\x05\x01\x08\x06\x06\x01\x02\x01\x00"
      "\x33\x00\x26\x00\x24\x00\x1d\x00\x20\x66\x9f\x92\x3c\xbf\x2d\x6e"
      "\x88\xf0\x12\xee\x3d\x89\xaf\xa3\x48\x29\x08\x98\xbb\x6d\x3b\xc4"
      "\xdb\x29\x4d\x8f\x97\x73\x2b\xa2\x0a\x00\x2d\x00\x02\x01\x01\x00"
      "\x2b\x00\x05\x04\x03\x04\x03\x03";

  var rawClientHello1 = List<int>.from(clientHello.codeUnits);
  var radom2 =
      "\x7c\xc4\x5b\x86\x56\xa1\x5e\xc4\x1d\xcc\xa9\xc2\x77\xe9\x5e\x38"
      "\x30\x8f\x6c\x4a\xba\xb8\xe8\xaa\xff\xca\x4b\x0f\xe6\x86\x6b\x15";
  var start = indexOfElements(rawClientHello1, radom2.codeUnits);
  rawClientHello1.replaceRange(start, start + 32, randomB);

  var sessionID2 =
      "\xdf\x16\x15\xec\x56\x96\x80\xb0\xd9\xb8\x22\xfa\x08\xea\x1c\xa0"
      "\x4e\x41\x14\x19\x20\xf2\x72\xe4\x10\xe2\x16\x7f\x2b\x31\x7a\x2c";
  start = indexOfElements(rawClientHello1, sessionID2.codeUnits);
  rawClientHello1.replaceRange(start, start + 32, randomB);

  var rawClientHello = List<int>.from(rawClientHello1);

  test('TLSBase', () {
    var res = TLSBase.parse(rawData: rawClientHello);
    expect(res.tlsVersion, TLSVersion.tls1_0);
    expect(res.contentType, ContentType.handshake);
    expect(res.build(),
        [ContentType.handshake.value] + TLSVersion.tls1_0.value + [0, 0]);
  });

  test('handshake', () {
    var res = Handshake.parse(rawData: rawClientHello);
    expect(res.tlsVersion, TLSVersion.tls1_0);
    expect(res.handshakeType, HandshakeType.clientHello);
    expect(res.handshakeTLSVersion, TLSVersion.tls1_2);
    expect(res.sessionID, randomB);
    expect(res.random, randomB);

    expect(
        res.build().sublist(5),
        [HandshakeType.clientHello.value] +
            [0, 0, 67] +
            TLSVersion.tls1_2.value +
            randomB +
            [32] +
            randomB);
  });

  test('ChangeSpec', () {
    var changeSpec = ChangeSpec(tlsVersion: TLSVersion.tls1_1);
    var res = changeSpec.build();
    expect(
        res,
        [ContentType.changeCipherSpec.value] +
            TLSVersion.tls1_1.value +
            [0, 1, 1]);
  });

  test('ApplicationData', () {
    var applicationData = ApplicationData(data: [1]);
    var res = applicationData.build();
    expect(
        res,
        [ContentType.applicationData.value] +
            TLSVersion.tls1_2.value +
            [0, 1, 1]);
  });

  test('extension', () {
    var extensions = Extension(type: [0, 0], data: [2]).build();
    expect(extensions, [0, 0, 0, 1, 2]);
  });

  test('extensionList', () {
    var extensionList = ExtensionList(list: [
      Extension(type: [0, 0], data: [2])
    ]).build();

    expect(extensionList, [0, 5] + [0, 0, 0, 1, 2]);
  });

  test('extensionList parse serverHello', () {
    var temp = "\x00\x2e"
        "\x00\x33\x00\x24\x00\x1d\x00\x20\xa1\x31\xbc\xa8\x54\xe5\xc9\xdb"
        "\x28\x00\x39\xdc\x5a\x2d\x6d\x10\xf9\x75\xce\x86\x2c\xcd\xe9\x67"
        "\xb6\xdd\x66\xe5\x5f\x74\xee\x0a"
        "\x00\x2b\x00\x02\x03\x04";
    var rawData = List<int>.from(temp.codeUnits);
    var extensionList = ExtensionList.parse(rawData: rawData);
    expect(extensionList.build(), rawData);
  });

  test('extensionList serverName', () {
    var temp = "\x00\x12"
        "\x00\x00\x00\x0e\x00\x0c\x00\x00\x09\x75\x69\x66\x30\x33\x2e\x74"
        "\x6f\x70";
    var rawData = List<int>.from(temp.codeUnits);
    var extensionList = ExtensionList.parse(rawData: rawData);

    expect(extensionList.list.length, 1);
    expect(extensionList.list[0].type, ExtensionType.serverName.value);
    expect(extensionList.list[0].data.length, 14);
    var newDomain = [1, 2, 3];
    extensionList.setServerName(newDomain);
    expect(extensionList.list[0].data, [0, 6, 0, 0, 3] + newDomain);
    expect(extensionList.build(), [0, 12, 0, 0, 0, 8, 0, 6, 0, 0, 3, 1, 2, 3]);
  });

  test('ApplicationData', () {
    var temp =
        "\x17\x03\x03\x00\x35\x07\x04\x81\xef\x24\xa0\x3a\xf0\xa7\x54\x65"
        "\xfd\x20\x34\x09\xea\x2e\x3e\xf3\x8c\x30\x34\xd9\xa5\xa9\xea\x0c"
        "\x96\xad\x16\x40\x13\xf7\x47\x29\xce\x8f\x65\x3f\xe9\x7f\x7d\x0d"
        "\x64\xea\xda\x7c\x87\x82\x59\x13\xbd\x2d";

    var rawData = List<int>.from(temp.codeUnits);
    var applicationData = ApplicationData.parse(rawData: rawData);

    expect(applicationData.tlsVersion, TLSVersion.tls1_2);
    expect(applicationData.build(), rawData);
  });

  test('clientCompressionMethod', () {
    var clientCompressionMethod =
        ClientCompressionMethod.parse(rawData: [1, 0]).build();

    expect(clientCompressionMethod, [1] + [0]);
  });

  test('ClientCipherSuites parse.', () {
    var temp = "\x00\x24"
        "\x13\x03\x13\x01\x13\x02\xcc\xa9\xcc\xa8\xc0\x2b\xc0\x2f\xc0\x2c"
        "\xc0\x30\xc0\x09\xc0\x13\xc0\x0a\xc0\x14\x00\x9c\x00\x9d\x00\x2f"
        "\x00\x35\x00\x0a";

    var rawData = List<int>.from(temp.codeUnits);
    var res = ClientCipherSuites.parse(rawData: rawData);
    expect(res.len, 36);
    expect(res.build(), temp.codeUnits);
  });

  test('clientHello parse.', () {
    var rawData = List<int>.from(rawClientHello);

    var res = ClientHello.parse(rawData: rawData);
    expect(res.handshakeType, HandshakeType.clientHello);
    expect(res.extensionList!.list.length, 10);
    expect(res.tlsVersion, TLSVersion.tls1_0);
    expect(res.handshakeTLSVersion, TLSVersion.tls1_2);
    expect(res.contentType, ContentType.handshake);
    expect(res.random, randomB);
    expect(res.sessionID, randomB);
    expect(res.clientCompressionMethod!.len, 1);
    expect(res.clientCipherSuites!.len, 36);

    expect(res.build(), rawClientHello1);
    expect(res.build(), rawData);

    res.extensionList!.setKeyShare(zeroList(), true);
    expect(res.extensionList!.getKeyShare(true), zeroList());
    res.extensionList!.setServerName([1, 2]);
  });

  test('serverHello parse', () {
    var temp =
        "\x16\x03\x03\x00\x7a\x02\x00\x00\x76\x03\x03\x09\xf7\x6c\x8f\x4c"
        "\x4d\x97\x2f\x45\xc8\x9d\x14\x05\x83\x4e\x21\xb5\xf3\x46\x6b\xb8"
        "\x6c\x23\x3a\x9c\x98\x6e\xd2\x4a\x88\x21\xe2\x20\xdf\x16\x15\xec"
        "\x56\x96\x80\xb0\xd9\xb8\x22\xfa\x08\xea\x1c\xa0\x4e\x41\x14\x19"
        "\x20\xf2\x72\xe4\x10\xe2\x16\x7f\x2b\x31\x7a\x2c\x13\x03\x00\x00"
        "\x2e\x00\x33\x00\x24\x00\x1d\x00\x20\x14\xaf\xf7\x4d\x6a\x3b\x37"
        "\xeb\x14\xd4\xa4\x31\xbc\x81\x21\x28\x74\x77\x01\x28\xe3\xc5\x48"
        "\x46\x96\x74\x00\xe4\xaa\xe4\xe3\x30\x00\x2b\x00\x02\x03\x04";

    var rawData = List<int>.from(temp.codeUnits);

    var res = ServerHello.parse(rawData: rawData);
    expect(res.tlsVersion, TLSVersion.tls1_2);
    expect(res.handshakeTLSVersion, TLSVersion.tls1_2);
    expect(res.build(), temp.codeUnits);
    expect(res.build(), rawData);

    res.extensionList!.setKeyShare(zeroList(), false);
    expect(res.extensionList!.getKeyShare(false), zeroList());
  });
}
