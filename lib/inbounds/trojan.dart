import 'dart:typed_data';

import 'package:quiver/collection.dart';
import 'package:crypto/crypto.dart';

import 'package:proxy/utils/utils.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/utils/const.dart';

enum ATYP{
  domain(3),
  ipv4(1),
  ipv6(4);

  const ATYP(this.value);
  final int value;
}

class TrojanRequest extends Link {
  bool isAuth = false;
  bool isParseDST = false;
  bool isTunnel = false;
  int authMethod = 0;
  List<int> content = [];

  List<int> pwdSHA224;

  TrojanRequest(
      {required super.client,
      required super.inboundStruct,
      required this.pwdSHA224}) {
    client.listen((data) async {
      if (isTunnel) {
        passToTunnel(data);
      } else if (!isAuth) {
        await auth(data);
      } else if (!isParseDST) {
        await parseDST(data);
      } else {
        await serverAdd(data);
      }
    }, onError: (e, s) async {
      await closeServer();
    }, onDone: () async {
      await closeServer();
    });
  }

  Future<void> parseDST(List<int> data) async {
    //{{{
    content += data;
    if (content.length < 3) {
      return;
    }

    if (content[1] == 3) {
      cmd = CmdType.udp;
    } else if (content[1] == 2) {
      cmd = CmdType.bind;
    }

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
      await closeClient();
      return;
    }

    var addressAndPortLength = addressEnd + 2;
    var trojanRequestLength = addressAndPortLength + 2; // with CRLF.
    if (content.length < trojanRequestLength) {
      return;
    }

    if (isDomain) {
      targetAddress = Address.fromRawAddress(
          content.sublist(3, addressEnd), AddressType.domain);
    } else {
      var address = content.sublist(2, addressEnd);
      if (atyp == 4) {
        targetAddress = Address.fromRawAddress(address, AddressType.ipv6);
      } else {
        targetAddress = Address.fromRawAddress(address, AddressType.ipv4);
      }
    }

    Uint8List byteList =
        Uint8List.fromList(content.sublist(addressEnd, addressAndPortLength));
    ByteData byteData = ByteData.sublistView(byteList);
    targetport = byteData.getUint16(0, Endian.big);

    content = content.sublist(trojanRequestLength);
    isParseDST = true;
    await bindServer();

    if (content.isNotEmpty) {
      await serverAdd(content);
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
    if (!listsEqual(pwd, pwdSHA224)) {
      isTunnel = true;
      passToTunnel([]);
      return;
    }
    content = content.sublist(58);

    userID = pwdSHA224;
    isAuth = true;
    await parseDST([]);
  } //}}}

  void passToTunnel(List<int> data) {
    content += data;
  }
}

class TrojanIn extends InboundStruct {
  List<int> pwdSHA224 = [];
  String? password;
  String? tunnelAddress;
  int? tunnelPort;

  TrojanIn({required super.config})
      : super(protocolName: 'trojan', protocolVersion: '1') {
    password = getValue(config, 'setting.password', '');
    tunnelAddress = getValue(config, 'setting.tunnelAddress', '');
    tunnelPort = getValue(config, 'setting.tunnelPort', 0);
    if (password == '' || inPort == 0 || inAddress == '') {
      throw 'trojan required "password", "address" and "port" in config.';
    }

    if (tunnelAddress == '' || tunnelPort == 0) {
      logger.config(
          "tunnelAddress and tunnelPort should be filled to avoid detection.");
    }

    pwdSHA224 = sha224.convert(password!.codeUnits).toString().codeUnits;
  }

  @override
  Future<void> bind() async {
    var server = await transportServer!.bind(inAddress, inPort);

    server.listen((client) {
      TrojanRequest(client: client, inboundStruct: this, pwdSHA224: pwdSHA224);
    }, onError: (e, s) {}, onDone: () {});
  }
}
