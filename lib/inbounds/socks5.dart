import 'dart:typed_data';
import 'dart:convert';

import 'package:proxy/inbounds/base.dart';
import 'package:proxy/utils/utils.dart';
import 'dart:io';

class Socks5Request extends Link {
  String fullURL = '';
  bool isAuth = false;
  bool isParseDST = false;
  int authMethod = 0;
  int socks5Version = 5;
  List<int> methods = [];
  List<int> content = [];

  void clientAdd(List<int> data) {
    try {
      client.add(data);
    } catch (_) {}
  }

  void serverAdd(List<int> data) {
    try {
      server.add(data);
    } catch (_) {}
  }

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
        parseDST([]);
      } else if (!isParseDST) {
        parseDST(data);
      } else {
        serverAdd(data);
      }
    }, onError: (e) {
      closeAll();
    }, onDone: () {
      closeAll();
    });
  }

  void closeAll() {
    try {
      client.close();
    } catch (_) {}
    try {
      server.close();
    } catch (_) {}
  }

  void bindServer() async {
    //{{{
    outboundStruct = inboundStruct.doRoute(this);
    try {
      server = await outboundStruct.connect2(this);
    } catch (e) {
      print(e);
      closeAll();
      return;
    }

    server.listen((event) {
      clientAdd(event);
    }, onDone: () {
      closeAll();
    }, onError: (e) {
      closeAll();
    });

    server.done.then((value) {
      closeAll();
    }, onError: (e) {
      closeAll();
    });
  } //}}}

  void handleCMD() {
    //{{{
    if (cmd == 1) {}

    bindServer();

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

  void parseDST(List<int> data) {
    //{{{
    content += data;
    if (content.length < 4) {
      return;
    }

    if (content[0] != socks5Version) {
      closeAll();
      return;
    }
    cmd = content[1];

    int addressLength;
    var atyp = content[3];
    InternetAddress internetAddress;

    if (atyp == 1) {
      typeOfAddress = 'ipv4';
      addressLength = 4;
      internetAddress = InternetAddress.fromRawAddress(
          Uint8List.fromList(content.sublist(4, addressLength)));
      targetAddress = internetAddress.address;
    } else if (atyp == 3) {
      typeOfAddress = 'domain';
      addressLength = atyp;
      targetAddress = utf8.decode(content.sublist(4, addressLength));
    } else if (atyp == 4) {
      typeOfAddress = 'ipv6';
      addressLength = 16;
      internetAddress = InternetAddress.fromRawAddress(
          Uint8List.fromList(content.sublist(4, addressLength)));
      targetAddress = internetAddress.address;
    } else {
      closeAll();
      return;
    }

    var addressAndPortLength = 4 + addressLength + 2;
    if (content.length < addressAndPortLength) {
      return;
    }

    Uint8List byteList =
        Uint8List.fromList(content.sublist(4, addressAndPortLength));
    ByteData byteData = ByteData.sublistView(byteList);
    targetport = byteData.getUint16(4 + addressLength, Endian.host);

    content = content.sublist(4 + addressAndPortLength);
    isParseDST = true;
    handleCMD();
  } //}}}

  void auth(List<int> data) {
    //{{{
    content += data;

    if (content[0] != socks5Version) {
      closeAll();
      return;
    }

    var nmethods = content[1];
    var authLength = 2 + nmethods;

    if (content.length < authLength) {
      return;
    }

    methods = content.sublist(2, nmethods);

    clientAdd([socks5Version, authMethod]);
    if (authMethod == 2) {
      // TODO password
    }
    isAuth = true;
    content = content.sublist(authLength);
  } //}}}

}

class Socks5In extends InboundStruct {
  late String address;
  late int port;

  Socks5In({required super.config})
      : super(protocolName: 'socks5', protocolVersion: '1.1') {
    address = getValue(config, 'setting.address', '');
    port = getValue(config, 'setting.port', 0);

    if (address == '' || port == 0) {
      throw 'socks5 required "address" and "port" in config.';
    }
  }

  @override
  Future<ServerSocket> bind2() async {
    var server = getServer()();

    await server.bind(address, port);

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
