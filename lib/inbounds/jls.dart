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
  List<int> rawData = [];
  List<int> plainText = [];

  int currentLen = 0;
  late List<int> sendData;

  JLSRequest(
      {required super.client,
      required super.inboundStruct,
      required this.jlsServerHandler}) {
    client.listen((data) async {
      await handleData(data);
    }, onError: (e, s) async {
      await closeServer();
    }, onDone: () async {
      await closeServer();
    });
  }

  Future<void> parseDST(List<int> data) async {
    //{{{
    if (data[0] == 3) {
      cmd = CmdType.udp;
    } else if (data[0] == 2) {
      cmd = CmdType.bind;
    }

    int addressEnd = 2;
    var atyp = data[1];
    bool isDomain = false;

    if (atyp == 1) {
      addressEnd += 4;
    } else if (atyp == 3) {
      isDomain = true;
      addressEnd += data[2] + 1;
    } else if (atyp == 4) {
      addressEnd += 16;
    } else {
      await closeClient();
      return;
    }

    var addressAndPortLength = addressEnd + 2;
    var trojanRequestLength = addressAndPortLength + 2; // with CRLF.
    if (data.length < trojanRequestLength) {
      return;
    }

    if (isDomain) {
      targetAddress = Address.fromRawAddress(
          data.sublist(3, addressEnd), AddressType.domain);
    } else {
      var address = data.sublist(2, addressEnd);
      if (atyp == 4) {
        targetAddress = Address.fromRawAddress(address, AddressType.ipv6);
      } else {
        targetAddress = Address.fromRawAddress(address, AddressType.ipv4);
      }
    }

    Uint8List byteList =
        Uint8List.fromList(data.sublist(addressEnd, addressAndPortLength));
    ByteData byteData = ByteData.sublistView(byteList);
    targetport = byteData.getUint16(0, Endian.big);

    data = data.sublist(trojanRequestLength);
    isParseDST = true;
    await bindServer();

    serverAdd(data);
  } //}}}

  List<int> waitRecord() {
    //{{{
    if (rawData.length < 5) {
      return [];
    }
    ByteData byteData =
        ByteData.sublistView(Uint8List.fromList(rawData.sublist(3, 5)));
    var len = byteData.getUint16(0, Endian.big);
    if (rawData.length - 5 < len) {
      return [];
    }
    var res = rawData.sublist(5, 5 + len);
    rawData = rawData.sublist(5 + len);
    return res;
  } //}}}

  Future<void> handleData(List<int> data) async {
    rawData += data;
    while (true) {
      var record = waitRecord();
      if (record.isEmpty) {
        return;
      }
      var res =
          await jlsServerHandler.jls.receive(ApplicationData(data: record));

      if (res.isEmpty) {
        continue;
      }

      if (!isParseDST) {
        await parseDST(res);
      } else {
        await serverAdd(res);
      }
    }
  }
}

class JLSIn extends InboundStruct {
  String password = '';
  String fallback = '';
  String iv = '';
  Duration? timeout;

  JLSIn({required super.config})
      : super(protocolName: 'jls', protocolVersion: '1') {
    password = getValue(config, 'setting.password', '');
    iv = getValue(config, 'setting.random', '');
    fallback = getValue(config, 'setting.fallback', 'apple.com');
    var sec = getValue(config, 'setting.timeout', 30);
    timeout = Duration(seconds: sec);

    if (password == '' || iv == '') {
      throw Exception('"password", "random",can not be empty in setting.');
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

      logger.info("test");
      if (!await handler.secure()) {
        logger.info("wrong jls client");
        await client.close();
        return;
      }

      JLSRequest(
          client: client, inboundStruct: this, jlsServerHandler: handler);
    }, onError: (e, s) {}, onDone: () {});
  }
}
