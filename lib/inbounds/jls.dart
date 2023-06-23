import 'dart:typed_data';

import 'package:proxy/obj_list.dart';
import 'package:proxy/transport/jls/jls.dart';
import 'package:proxy/transport/jls/server.dart';
import 'package:proxy/transport/jls/tls/base.dart';

import 'package:proxy/utils/utils.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/utils/const.dart';

class JLSRequest extends Link {
  JLSServerHandler jlsServerHandler;
  bool isParseDST = false;
  int authMethod = 0;
  List<int> content = [];

  int currentLen = 0;
  late List<int> sendData;

  JLSRequest(
      {required super.client,
      required super.inboundStruct,
      required this.jlsServerHandler}) {
    client.listen((data) async {
      if (!isParseDST) {
        await parseDST(data);
      } else {
        await handleData(data);
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

    await handleData([]);
    content = [];
  } //}}}

  List<int> waitRecord() {
    if (content.length < 5) {
      return [];
    }
    ByteData byteData =
        ByteData.sublistView(Uint8List.fromList(content.sublist(3, 5)));
    var len = byteData.getUint16(0, Endian.big);
    if (content.length - 5 < len) {
      return [];
    }
    var res = content.sublist(0, 5 + len);
    content = content.sublist(5 + len);
    return res;
  }

  Future<void> handleData(List<int> data) async {
    content += data;
    while (true) {
      var record = waitRecord();
      if (record.isEmpty) {
        return;
      }
      var res = await jlsServerHandler.jls
          .receive(ApplicationData.parse(rawData: record));
      serverAdd(res);
    }
  }

  void passToTunnel(List<int> data) {
    content += data;
  }
}

class JLSIn extends InboundStruct {
  String password = '';
  String fallback = '';
  String iv = '';
  Duration? timeout;

  JLSIn({required super.config})
      : super(protocolName: 'trojan', protocolVersion: '1') {
    password = getValue(config, 'setting.password', '');
    iv = getValue(config, 'setting.random', '');
    fallback = getValue(config, 'setting.fallback', 'apple.com');
    var sec = getValue(config, 'setting.timeout', 10);
    timeout = Duration(seconds: sec);

    if (password == '' || iv == '') {
      throw Exception(
          '"password", "random", "fallback" can not be empty in setting.');
    }
  }

  @override
  Future<void> bind() async {
    var server = await transportServer!.bind(inAddress, inPort);

    server.listen((client) async {
      var jlsServer = JLSServer(
          pwdStr: password,
          ivStr: iv,
          fingerPrint: jlsFringerPrintList['default']!);

      var handler = JLSServerHandler(
        client: client,
        jls: jlsServer,
        fallbackWebsite: fallback,
        jlsTimeout: timeout!,
      );

      if (!await handler.secure()) {
        devPrint('failed to secure.');
        return;
      }

      JLSRequest(
          client: client, inboundStruct: this, jlsServerHandler: handler);
    }, onError: (e, s) {}, onDone: () {});
  }
}
