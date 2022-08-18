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
    Future.delayed(Duration(seconds: 10), () {
      if (!isParsed) {
        // timeout
        closeAll();
      }
    });
    client = client;

    client.listen(
      (data) async {
        if (!isParsed) {
          parse(data);
          if (!isParsed) {
            return;
          }
          inboundStruct.doRoute(this);

          try {
            server = await outboundStruct.connect(this);
            server.listen((event) {
              client.add(event);
            }, onDone: () {
              closeAll();
            }, onError: () {
              closeAll();
            });
          } catch (_) {
            closeAll();
            return;
          }

          if (method == 'CONNECT') {
            // server.add(content);
            client.add(buildConnectionResponse());
          } else {
            server.add(buildHTTP());
          }
          try {
            await server.done;
          } catch (_) {}
          closeAll();
        } else {
          handle(data);
        }
      },
    );
  }

  void handle(List<int> data) {
    client.close();
  }

  void closeAll() {
    client.close();
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
    inProxyProtocolVersion = temp2[2];

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
    var temp = '$method $targetUri $inProxyProtocolVersion\r\n';
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
