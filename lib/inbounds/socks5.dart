import 'dart:typed_data';

import 'package:proxy/inbounds/base.dart';
import 'package:proxy/utils/utils.dart';

class Socks5Request extends Link {
  bool isAuth = false;
  bool isParseDST = false;
  int authMethod = 0;
  int socks5Version = 5;
  List<int> methods = [];
  List<int> content = [];

  Socks5Request({required super.client, required super.inboundStruct}) {
    Future.delayed(Duration(seconds: 3), () async {
      if (!isAuth) {
        // timeout
        await closeAll();
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
    }, onError: (e) async {
      await closeAll();
    }, onDone: () async {
      await closeAll();
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
      await closeAll();
      return;
    }
    cmd = content[1];

    int addressEnd = 4;
    var atyp = content[3];
    bool isDomain = false;

    if (atyp == 1) {
      addressEnd += 4;
    } else if (atyp == 3) {
      addressEnd += content[4] + 1;
      isDomain = true;
    } else if (atyp == 4) {
      addressEnd += 16;
    } else {
      await closeAll();
      return;
    }

    var addressAndPortLength = addressEnd + 2;
    if (content.length < addressAndPortLength) {
      return;
    }

    if (isDomain) {
      targetAddress =
          Address.fromRawAddress(content.sublist(5, addressEnd), 'domain');
    } else {
      targetAddress =
          Address.fromRawAddress(content.sublist(4, addressEnd), 'ip');
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

  Future<void> auth(List<int> data) async {
    //{{{
    content += data;

    if (content[0] != socks5Version) {
      await closeAll();
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
  Future<void> bind() async {
    var server = getServer();

    await server.bind(inAddress, inPort);

    server.listen((client) async {
      totalClient += 1;
      Socks5Request(client: client, inboundStruct: this);
      try {
        await client.done;
      } catch (_) {}
      totalClient -= 1;
    }, onError: (e) {
      print(e);
    });
  }
}
