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
        await auth(data);
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

    if (content.length < 3) {
      return;
    }

    cmd = content[0];

    int addressEnd = 2;
    var atyp = content[1];
    bool isDomain = false;

    if (atyp == 1) {
      addressEnd += 4;
    } else if (atyp == 3) {
      isDomain = true;
      addressEnd += content[2] + 1;
    } else if (atyp == 4) {
      addressEnd += 16;
    } else {
      closeAll();
      return;
    }

    var addressAndPortLength = addressEnd + 2;
    var trojanRequestLength = addressAndPortLength + 2; // with crlf.
    if (content.length < trojanRequestLength) {
      return;
    }

    if (isDomain) {
      targetAddress =
          Address.fromRawAddress(content.sublist(3, addressEnd), 'domain');
    } else {
      targetAddress =
          Address.fromRawAddress(content.sublist(2, addressEnd), 'ip');
    }

    Uint8List byteList =
        Uint8List.fromList(content.sublist(addressEnd, addressAndPortLength));
    ByteData byteData = ByteData.sublistView(byteList);
    targetport = byteData.getUint16(0, Endian.big);

    content = content.sublist(trojanRequestLength);
    isParseDST = true;
    await bindServer();

    if (content.isNotEmpty) {
      serverAdd(content);
    }
    content = [];
  } //}}}

  Future<void> auth(List<int> data) async {
    //{{{
    content += data;
    if (content.length < 58) {
      // 56 + 2
      return;
    }

    var pwd = content.sublist(0, 56);
    var tempCrlf = content.sublist(56, 58);
    if (!ListEquality().equals(pwd, pwdSHA224)) {
      isTunnel = true;
      passToTunnel([]);
      return;
    }
    content = content.sublist(58);

    if (ListEquality().equals(tempCrlf, [0, 0])) {
      isGetRRSID = 1; // need to get.
    }
    isAuth = true;
    await parseDST([]);
  } //}}}

  void passToTunnel(List<int> data) {
    content += data;
  }
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
      throw 'trojan required "address", "port", "tunnelAddress", "tunnelPort" and "password" in config.';
    }
    pwdSHA224 = sha224.convert(password.codeUnits).toString().codeUnits;
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
