import 'dart:async';
import 'dart:convert';

import 'package:proxy/inbounds/base.dart';
import 'package:proxy/transport/server/base.dart';
import 'package:proxy/utils/utils.dart';

class HTTPRequest extends Link {
  String fullURL = '';
  bool isParsed = false;
  List<int> header = [];
  List<int> content = [];

  HTTPRequest({required super.client, required super.inboundStruct}) {
    client.listen((data) async {
      if (isParsed) {
        serverAdd(data);
      } else {
        await parse(data);
      }
    }, onError: (e, s) {
      closeServer();
    }, onDone: () {
      closeServer();
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
    } else {
      targetUri = Uri.parse(fullURL);
    }
    targetAddress = Address(targetUri!.host);
    targetport = targetUri!.port;
    isParsed = true;

    if (!await bindServer()) {
      closeAll();
      return;
    }

    if (method == 'CONNECT') {
      clientAdd(buildConnectionResponse());
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
  RRSServerSocket? rrsServerSocket;

  HTTPIn({required super.config})
      : super(protocolName: 'http', protocolVersion: '1.1') {
    if (inAddress == '' || inPort == 0) {
      throw 'http required "address" and "port" in config.';
    }
  }

  void listen() {
    rrsServerSocket!.listen((client) {
      HTTPRequest(client: client, inboundStruct: this);
    }, onError: (e, s) {}, onDone: () {});
  }

  @override
  Future<void> bind() async {
    rrsServerSocket = await transportServer!.bind(inAddress, inPort);
    listen();
  }
}
