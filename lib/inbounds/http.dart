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
      if (isParsed) {
        serverAdd(data);
      } else {
        parse(data);
        if (!isParsed) {
          return;
        }
        await bindServer();

        if (method == 'CONNECT') {
          clientAdd(buildConnectionResponse());
        } else {
          serverAdd(buildHTTP());
        }
      }
    }, onError: (e) {
      closeAll();
    }, onDone: () {
      closeAll();
    });
  }

  void parse(List<int> data) {
    //{{{
    content += data;

    var pos1 = indexOfElements(content, '\r\n'.codeUnits);
    if (pos1 == 0) {
      // badRequest.
      closeAll();
      return;
    }
    var pos2 = indexOfElements(content, '\r\n\r\n'.codeUnits, pos1 + 2);
    if (pos2 == -1 || pos1 == -1) {
      return;
    }

    var firstLine = utf8.decode(content.sublist(0, pos1));
    var temp2 = firstLine.split(' ');
    if (temp2.length != 3) {
      isValidRequest = false;
      closeAll();
      return;
    }
    method = temp2[0];
    fullURL = temp2[1];
    protocolVersion = temp2[2];

    header = content.sublist(pos1 + 2, pos2);

    if (method == 'CONNECT') {
      targetUri = Uri.parse('none://$fullURL');
      content = content.sublist(pos2 + 4);
    } else {
      targetUri = Uri.parse(fullURL);
    }
    targetAddress = Address(targetUri.host);
    targetport = targetUri.port;
    isValidRequest = true;
    isParsed = true;
    return;
  } //}}}

  List<int> buildConnectionResponse() {
    //{{{
    var temp = '$protocolVersion 200 Connection Established\r\n\r\n';
    return temp.codeUnits;
  } //}}}

  List<int> buildHTTP() {
    //{{{
    return content;
    var temp = '$method $targetUri $protocolVersion\r\n';
    var temp2 = temp.codeUnits;
    if (header != []) {
      temp2 += header + '\r\n'.codeUnits;
    }
    temp2 += '\r\n'.codeUnits + content;
    return temp2;
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
