import 'dart:convert';

import 'package:proxy/inbounds/base.dart';
import 'package:proxy/utils/utils.dart';
import 'dart:io';

class HTTPRequest extends Link {
  String fullURL = '';
  bool isParsed = false;
  List<int> header = [];
  List<int> content = [];

  HTTPRequest({required super.client, required super.inboundStruct}) {
    Future.delayed(Duration(seconds: 3), () {
      if (!isParsed) {
        // timeout
        closeAll();
      }
    });

    client.listen((data) async {
      print(data);
      if (isParsed) {
        serverAdd(data);
      } else {
        await parse(data);
      }
    }, onError: (e) {
      closeAll();
    }, onDone: () {
      closeAll();
    });
  }

  Future<void> parse(List<int> data) async {
    //{{{
    content += data;

    var pos1 = indexOfElements(content, '\r\n\r\n'.codeUnits);
    if (pos1 == -1) {
      return;
    }
    var pos2 = indexOfElements(content.sublist(0, pos1 + 2), '\r\n'.codeUnits);

    var firstLine = utf8.decode(content.sublist(0, pos2));
    var temp2 = firstLine.split(' ');
    if (temp2.length != 3) {
      closeAll();
      return;
    }
    method = temp2[0];
    fullURL = temp2[1];
    protocolVersion = temp2[2];

    header = content.sublist(pos2 + 2, pos1 + 2); // with \r\n

    if (method == 'CONNECT') {
      targetUri = Uri.parse('none://$fullURL');
      content = content.sublist(pos1 + 4);
      print(buildConnectionResponse());
      clientAdd(buildConnectionResponse());
    } else {
      targetUri = Uri.parse(fullURL);
    }
    targetAddress = Address(targetUri.host);
    targetport = targetUri.port;
    isParsed = true;

    if (!await bindServer()) {
      return;
    }

    if (content.isNotEmpty) {
      serverAdd(content);
    }
    content = [];
    return;
  } //}}}

  List<int> buildConnectionResponse() {
    //{{{
    var temp = '$protocolVersion 200 Connection Established\r\n\r\n';
    return temp.codeUnits;
  } //}}}
}

class HTTPIn extends InboundStruct {
  HTTPIn({required super.config})
      : super(protocolName: 'http', protocolVersion: '1.1') {
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
      HTTPRequest(client: client, inboundStruct: this);
      try {
        await client.done;
      } catch (_) {}
      totalClient -= 1;
    });
    return server;
  }
}
