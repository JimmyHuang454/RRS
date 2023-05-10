import 'dart:async';
import 'dart:typed_data';

import 'package:proxy/inbounds/base.dart';
import 'package:proxy/utils/utils.dart';
import 'package:proxy/utils/const.dart';

class Socks5Request extends Link {
  bool isAuth = false;
  bool isParseDST = false;
  int authMethod = 0;
  int socks5Version = 5;
  List<int> methods = [];
  List<int> content = [];

  Socks5Request({required super.client, required super.inboundStruct}) {
    client.listen((data) async {
      content += data;
      if (!isAuth) {
        await auth();
      }

      if (!isParseDST && isAuth) {
        await parseRequest();
      }

      if (!isParseDST || !isAuth || content.isEmpty) {
        return;
      }

      if (streamType == StreamType.tcp) {
        await serverAdd(content);
        content = [];
      } else {
        handleUDP(content);
      }
    }, onError: (e, s) async {
      await closeAll();
    }, onDone: () async {
      await closeAll();
    });
  }

  Future<void> handleCMD() async {
    //{{{
    streamType = StreamType.tcp;

    if (cmd == CmdType.connect) {
      // CONNECTING
      var isConnectedServer = await bindServer();
      int rep = isConnectedServer ? 0 : 1;
      var res = [
        socks5Version,
        rep,
        0,
      ];
      var addressAndPort = [
        1,
        0,
        0,
        0,
        0,
        0,
        0
      ]; //BIND.ADDR and port alwayes return 0;
      res += addressAndPort;

      await clientAdd(res);
      isValidRequest = true;
      if (!isConnectedServer) {
        await closeAll();
      }
    } else if (cmd == CmdType.udp) {
      streamType = StreamType.udp;
      throw "TODO";
    } else if (cmd == CmdType.bind) {
      // BIND TODO
      throw "TODO";
    } else {
      throw "UNKNOW";
    }
  } //}}}

  Future<int> parseAddress() async {
    //{{{
    if (content.length < 5) {
      return -1;
    }

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
      return -1;
    }

    var addressAndPortLength = addressEnd + 2;
    if (content.length < addressAndPortLength) {
      return -1;
    }

    if (isDomain) {
      targetAddress = Address.fromRawAddress(
          content.sublist(5, addressEnd), AddressType.domain);
    } else {
      var address = content.sublist(4, addressEnd);
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

    return addressAndPortLength;
  } //}}}

  Future<void> parseRequest() async {
    //{{{
    if (content.length < 5) {
      return;
    }

    if (content[0] != socks5Version) {
      await closeAll();
      return;
    }

    if (content[1] == 3) {
      cmd = CmdType.udp;
    } else if (content[1] == 2) {
      cmd = CmdType.bind;
    }

    var addressAndPortLength = await parseAddress();
    if (addressAndPortLength == -1) {
      return;
    }

    content = content.sublist(addressAndPortLength);
    await handleCMD();
    isParseDST = true;
  } //}}}

  Future<void> auth() async {
    //{{{
    if (content.length < 3) {
      return;
    }

    var clientVersion = content[0];
    if (clientVersion != socks5Version) {
      await closeAll();
      throw 'mismatch clientVersion.';
    }

    int nmethods = content[1];
    var authLength = 2 + nmethods;

    if (content.length < authLength) {
      return;
    }

    // +----+----------+----------+
    // |VER | NMETHODS | METHODS  |
    // +----+----------+----------+
    // | 1  |    1     | 1 to 255 |
    // +----+----------+----------+
    methods = content.sublist(2, authLength);

    // only supports 'NO AUTHENTICATION REQUIRED' method.
    if (!methods.contains(0)) {
      await clientAdd([socks5Version, 0xFF]); // tell client to close.
      await closeAll();
      return;
    }
    await clientAdd([socks5Version, 0]); // ok.

    content = content.sublist(authLength);
    isAuth = true;
  } //}}}

  Future<void> handleUDP(List<int> data) async {
    //{{{
  } //}}}
}

class Socks5In extends InboundStruct {
  Socks5In({required super.config})
      : super(protocolName: 'socks5', protocolVersion: '5') {
    if (inAddress == '' || inPort == 0) {
      throw 'http required "address" and "port" in config.';
    }
  }

  @override
  Future<void> bind() async {
    var server = await transportServer!.bind(inAddress, inPort);
    server.listen((client) {
      Socks5Request(client: client, inboundStruct: this);
    }, onError: (e, s) {}, onDone: () {});
  }
}
