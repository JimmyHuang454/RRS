import 'dart:convert';

import 'package:proxy/inbounds/base.dart';
import 'package:proxy/utils/utils.dart';
import 'dart:io';

class HTTPRequest extends Link {
  String fullURL = '';
  String inProxyProtocolVersion = '';
  bool isParsed = false;
  List<int> header = [];
  List<int> content = [];

  HTTPRequest(Socket client, InboundStruct inboundStruct)
      : super(client, inboundStruct) {
    Future.delayed(Duration(seconds: timeout), () {
      if (!isParsed) {
        // timeout
        closeAll();
      }
    });

    client.listen(
      (data) async {},
    );
  }

  void closeAll() {
    client.close();
  }

  void parse(List<int> data) {
    //{{{
    if (isParsed) {
      return;
    }

    var pos1 = indexOfElements(data, '\r\n'.codeUnits);
    var pos2 = indexOfElements(data, '\r\n\r\n'.codeUnits, pos1 + 2);
    if (pos2 == -1 || pos1 == -1 || pos1 == 0) {
      return;
    }
    isParsed = true;

    var firstLine = utf8.decode(data.sublist(0, pos1));
    var temp2 = firstLine.split(' ');
    if (temp2.length != 3) {
      isValidRequest = false;
      client.close();
      return;
    }
    method = temp2[0];
    fullURL = temp2[1];
    inProxyProtocolVersion = temp2[2];

    if (method == 'CONNECT') {
      targetUri = Uri.parse('none://$fullURL');
    } else {
      targetUri = Uri.parse(fullURL);
    }
    isValidRequest = true;
    return;
  } //}}}
}

class HTTPIn extends InboundStruct {
  late String address;
  late int port;

  HTTPIn({required super.config})
      : super(protocolName: 'http', protocolVersion: '1.1') {
    address = getValue(config, 'setting.address', '');
    port = getValue(config, 'setting.port', 0);

    if (address == '' || port == 0) {
      throw 'http required "address" and "port" in config.';
    }
  }

  @override
  Future<ServerSocket> bind2() async {
    var server = getServer()();

    await server.bind(address, port);

    server.listen(
      (client) async {
        totalClient += 1;
        HTTPRequest(client, this);
        await client.done;
        totalClient -= 1;
      },
    );
    return server;
  }
}
