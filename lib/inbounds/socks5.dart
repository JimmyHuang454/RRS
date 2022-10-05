import 'dart:async';
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
    // Future.delayed(Duration(seconds: 3), () async {
    //   if (!isAuth) {
    //     // timeout
    //     await closeAll();
    //   }
    // });

    client.listen((data) async {
      if (!isAuth) {
        auth(data);
        await parseRequest([]);
      } else if (!isParseDST) {
        await parseRequest(data);
      } else if (streamType == 'TCP') {
        serverAdd(data);
      } else {
        handleUDP(data);
      }
    }, onError: (e) {
      devPrint('Socks5Request listen: $e');
      closeAll();
    }, onDone: () async {
      closeAll();
    });
  }

  Future<void> handleCMD() async {
    //{{{
    if (cmd == 1) {
      // CONNECTING
      var isConnectedServer = await bindServer();
      int rep = isConnectedServer ? 0 : 1;
      var res = [5, rep, 0, 1, 0, 0, 0, 0, 0, 0];
      // res.add(1); // ipv4
      // res += Uint8List(2)
      //   ..buffer.asByteData().setInt16(0, server.remotePort, Endian.big);
      clientAdd(res);
      isValidRequest = true;
      if (!isConnectedServer) {
        closeAll();
      }
    } else if (cmd == 3) {
      // UDP TODO
      streamType = 'UDP';
      throw "TODO";
    } else if (cmd == 2) {
      // BIND TODO
      throw "TODO";
    } else {
      throw "UNKNOW";
    }
  } //}}}

  Future<int> parseAddress(List<int> data) async {
    //{{{
    if (data.length < 5) {
      return -1;
    }

    int addressEnd = 4;
    var atyp = data[3];
    bool isDomain = false;

    if (atyp == 1) {
      addressEnd += 4;
    } else if (atyp == 3) {
      addressEnd += data[4] + 1;
      isDomain = true;
    } else if (atyp == 4) {
      addressEnd += 16;
    } else {
      closeAll();
      return -1;
    }

    var addressAndPortLength = addressEnd + 2;
    if (data.length < addressAndPortLength) {
      return -1;
    }

    if (isDomain) {
      targetAddress =
          Address.fromRawAddress(data.sublist(5, addressEnd), 'domain');
    } else {
      targetAddress = Address.fromRawAddress(data.sublist(4, addressEnd), 'ip');
    }

    Uint8List byteList =
        Uint8List.fromList(data.sublist(addressEnd, addressAndPortLength));
    ByteData byteData = ByteData.sublistView(byteList);
    targetport = byteData.getUint16(0, Endian.big);

    return addressAndPortLength;
  } //}}}

  Future<void> parseRequest(List<int> data) async {
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

    var addressAndPortLength = await parseAddress(content);
    if (addressAndPortLength == -1) {
      return;
    }

    content = content.sublist(addressAndPortLength);
    await handleCMD();
    isParseDST = true;

    if (streamType == 'TCP') {
      if (content.isNotEmpty) {
        serverAdd(content);
      }
      content = [];
    } else {
      handleUDP([]);
    }
  } //}}}

  Future<void> auth(List<int> data) async {
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

  Future<void> handleUDP(List<int> data) async {
    //{{{
    content += data;

    var addressAndPortLength = await parseAddress(content);
    if (addressAndPortLength == -1) {
      return;
    }

    // var frag = content[2];
    // var atyp = content[3];

    content = content.sublist(addressAndPortLength);

    serverAdd(content);
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
    var server = await getServer().bind(inAddress, inPort);

    server.listen((client) {
      Socks5Request(client: client, inboundStruct: this);
    }, onError: (e) {
      print(e);
    }, onDone: () {});
  }
}
