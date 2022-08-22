import 'dart:typed_data';
import 'dart:convert';

import 'package:proxy/inbounds/base.dart';
import 'dart:io';

class Socks5Request extends Link {
  bool isAuth = false;
  bool isParseDST = false;
  int authMethod = 0;
  int socks5Version = 5;
  List<int> methods = [];
  List<int> content = [];

  Socks5Request({required super.client, required super.inboundStruct}) {
    Future.delayed(Duration(seconds: 3), () {
      if (!isAuth) {
        // timeout
        closeAll();
      }
    });

    client.listen((data) async {
      if (!isAuth) {
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

    if (!await bindServer()) {
      return;
    }

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
    if (content.length < addressAndPortLength) {
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

    content = content.sublist(addressAndPortLength);
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

    if (content[0] != socks5Version) {
      closeAll();
      return;
    }

    int nmethods = content[1];
    var authLength = 2 + nmethods;

    if (content.length < authLength) {
      return;
    }

    // 5 1 0
    methods = content.sublist(2, authLength);

    clientAdd([socks5Version, authMethod]);
    if (authMethod == 2) {
      // TODO password
    }
    isAuth = true;
    content = content.sublist(authLength);
  } //}}}

}

class Socks5In extends InboundStruct {
  Socks5In({required super.config})
      : super(protocolName: 'socks5', protocolVersion: '1.1') {
    if (inAddress == '' || inPort == 0) {
      throw 'http required "address" and "port" in config.';
    }
  }

  @override
  Future<ServerSocket> bind2() async {
    var server = getServer()();

    await server.bind(inAddress, inPort);

    server.listen((client) async {
      totalClient += 1;
      Socks5Request(client: client, inboundStruct: this);
      try {
        await client.done;
      } catch (_) {}
      totalClient -= 1;
    });
    return server;
  }
}
