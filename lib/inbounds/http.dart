import 'dart:convert';

import 'package:proxy/inbounds/base.dart';
import 'package:proxy/utils/utils.dart';
import 'dart:io';

class HTTPRequest extends Link {
  String fullURL = '';
  bool isParsed = false;
  List<int> header = [];
  List<int> content = [];

  void clientSend(List<int> data) {
    try {
      client.add(data);
    } catch (_) {}
  }

  void serverSend(List<int> data) {
    try {
      server.add(data);
    } catch (_) {}
  }

  HTTPRequest({required super.client, required super.inboundStruct}) {
    Future.delayed(Duration(seconds: 3), () {
      if (!isParsed) {
        // timeout
        closeAll();
      }
    });

    client.listen((data) async {
      if (!isParsed) {
        parse(data);
        if (!isParsed) {
          return;
        }
        outboundStruct = inboundStruct.doRoute(this);

        try {
          server = await outboundStruct.connect2(this);
        } catch (e) {
          print(e);
          closeAll();
          return;
        }

        server.listen((event) {
          clientSend(event);
        }, onDone: () {
          closeAll();
        }, onError: (e) {
          closeAll();
        });

        if (method == 'CONNECT') {
          clientSend(buildConnectionResponse());
        } else {
          serverSend(buildHTTP());
        }
        try {
          await server.done;
        } catch (_) {}
        closeAll();
      } else {
        handle(data);
      }
    }, onError: (e) {
      closeAll();
    }, onDone: () {
      closeAll();
    });
  }

  void handle(List<int> data) {
    serverSend(data);
  }

  void closeAll() {
    try {
      client.close();
    } catch (_) {}
    try {
      server.close();
    } catch (_) {}
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
    content = content.sublist(pos2 + 4);

    if (method == 'CONNECT') {
      targetUri = Uri.parse('none://$fullURL');
    } else {
      targetUri = Uri.parse(fullURL);
    }
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
