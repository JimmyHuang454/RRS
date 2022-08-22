import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:proxy/utils/utils.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:crypto/crypto.dart';

class TrojanRequest extends Link {
  bool isAuth = false;
  bool isParseDST = false;
  bool isTunnel = false;
  int isGetRRSID = 0;
  int authMethod = 0;
  int socks5Version = 5;
  List<int> content = [];
  List<int> pwdSHA224 = [];

  TrojanRequest(
      {required super.client,
      required super.inboundStruct,
      required this.pwdSHA224}) {
    Future.delayed(Duration(seconds: 3), () {
      if (!isAuth) {
        isTunnel = true;
      }
    });

    client.listen((data) async {
      if (isTunnel) {
        passToTunnel(data);
      } else if (!isAuth) {
        auth(data);
        await parseDST([]);
      } else if (!isParseDST) {
        await parseDST(data);
      } else {
        serverAdd(data);
      }
    }, onError: (e) {
      closeAll();
    }, onDone: () {
      closeAll();
    });
  }

  Future<void> handleCMD() async {
    //{{{
    if (cmd == 1) {}

    await bindServer();

    int rep = 0;
    var res = [5, rep, 0];
    // res.add(server.remoteAddress.address.codeUnits.length);
    res.add(1); // ipv4
    res += server.remoteAddress.rawAddress;
    res += Uint8List(2)
      ..buffer.asByteData().setInt16(0, server.remotePort, Endian.big);
    clientAdd(res);
    isValidRequest = true;
  } //}}}

  Future<void> parseDST(List<int> data) async {
    //{{{
    content += data;
    if (isGetRRSID == 1) {
      if (content.length < 56) {
        return;
      }
      userID = content.sublist(0, 56);
      content = content.sublist(56);
      isGetRRSID = 2; // got it.
    }

    if (content.length < 5) {
      return;
    }

    if (content[0] != socks5Version) {
      closeAll();
      return;
    }
    cmd = content[1];

    int addressEnd = 4;
    var atyp = content[3];

    if (atyp == 1) {
      typeOfAddress = 'ipv4';
      addressEnd += 4;
    } else if (atyp == 3) {
      typeOfAddress = 'domain';
      addressEnd += content[4] + 1;
    } else if (atyp == 4) {
      typeOfAddress = 'ipv6';
      addressEnd += 16;
    } else {
      closeAll();
      return;
    }

    var addressAndPortLength = addressEnd + 2;
    var trojanRequestLength = addressAndPortLength + 4;
    if (content.length < trojanRequestLength) {
      return;
    }

    if (typeOfAddress == 'domain') {
      targetAddress = utf8.decode(content.sublist(5, addressEnd));
    } else {
      var internetAddress = InternetAddress.fromRawAddress(
          Uint8List.fromList(content.sublist(4, addressEnd)));
      targetAddress = internetAddress.address;
    }

    Uint8List byteList =
        Uint8List.fromList(content.sublist(addressEnd, addressAndPortLength));
    ByteData byteData = ByteData.sublistView(byteList);
    targetport = byteData.getUint16(0, Endian.big);

    content = content.sublist(trojanRequestLength);
    await handleCMD();

    if (content.isNotEmpty) {
      serverAdd(content);
    }
    content = [];
    isParseDST = true;
  } //}}}

  void auth(List<int> data) {
    //{{{
    content += data;
    if (content.length < 72) {
      return;
    }

    var pwd = content.sublist(0, 56);
    var temp = content.sublist(56, 72);
    if (!ListEquality().equals(pwd, pwdSHA224)) {
      isTunnel = true;
      return;
    }
    content = content.sublist(72);

    if (ListEquality().equals(temp, [0, 0, 0, 0])) {
      isGetRRSID = 1; // need to get.
    }
    isAuth = true;
  } //}}}

  void passToTunnel(List<int> data) {}
}

class TrojanIn extends InboundStruct {
  List<int> pwdSHA224 = [];
  late String password;
  late String tunnelAddress;
  late int tunnelPort;

  TrojanIn({required super.config})
      : super(protocolName: 'trojan', protocolVersion: '1') {
    password = getValue(config, 'setting.password', '');
    tunnelAddress = getValue(config, 'setting.tunnelAddress', '');
    tunnelPort = getValue(config, 'setting.tunnelPort', 0);
    if (inAddress == '' ||
        inPort == 0 ||
        password == '' ||
        tunnelAddress == '') {
      throw 'http required "address", "port", "tunnelAddress", "tunnelPort" and "password" in config.';
    }
    pwdSHA224 = sha224.convert(password.codeUnits).bytes;
  }

  @override
  Future<ServerSocket> bind2() async {
    var server = getServer()();

    await server.bind(inAddress, inPort);

    server.listen((client) async {
      totalClient += 1;
      TrojanRequest(client: client, inboundStruct: this, pwdSHA224: pwdSHA224);
      try {
        await client.done;
      } catch (_) {}
      totalClient -= 1;
    });
    return server;
  }
}
