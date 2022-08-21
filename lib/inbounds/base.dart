import 'dart:io';

import 'package:proxy/outbounds/base.dart';
import 'package:proxy/transport/server/base.dart';
import 'package:proxy/obj_list.dart';
import 'package:proxy/utils/utils.dart';

class Link {
  Socket client; // in
  late Socket server; // out

  late Uri targetUri; // if it's a HTTP request.
  String method = 'GET';
  int cmd = 0;

  String typeOfAddress = 'domain'; // domain | ipv4 | ipv6
  String targetAddress = '';
  int targetport = 0;
  String streamType = 'TCP'; // TCP | UDP

  String protocolVersion = '';
  String userID = 'none';
  bool isTLS = false;
  bool isHTTPRequest = false;
  bool isBitcont = false;
  int timeout = 100;
  bool isValidRequest = false;

  InboundStruct inboundStruct;
  late OutboundStruct outboundStruct; // assign after routing.

  Link({required this.client, required this.inboundStruct});

  void closeAll() {
    try {
      client.close();
    } catch (_) {}
    try {
      server.close();
    } catch (_) {}
  }

  void clientAdd(List<int> data) {
    try {
      client.add(data);
    } catch (_) {}
  }

  void serverAdd(List<int> data) {
    try {
      server.add(data);
    } catch (_) {}
  }

  Future<void> bindServer() async {
    outboundStruct = inboundStruct.doRoute(this);
    try {
      server = await outboundStruct.connect2(this);
    } catch (e) {
      print(e);
      closeAll();
      return;
    }

    server.listen((event) {
      clientAdd(event);
    }, onDone: () {
      closeAll();
    }, onError: (e) {
      closeAll();
    });

    server.done.then((value) {
      closeAll();
    }, onError: (e) {
      closeAll();
    });
  }
}

abstract class InboundStruct {
  String protocolName;
  String protocolVersion;
  late String inAddress;
  late int inPort;
  late String tag;
  late String inStream;
  late String route;

  Map<String, dynamic> config;

  int totalClient = 0;

  InboundStruct(
      {required this.protocolName,
      required this.protocolVersion,
      required this.config}) {
    tag = config['tag'];
    inStream = getValue(config, 'inStream', '');
    route = getValue(config, 'route', '');
    inAddress = getValue(config, 'setting.address', '');
    inPort = getValue(config, 'setting.port', 0);

    if (inStream == '' || route == '') {
      throw 'inStream and route can NOT be null.';
    }
  }

  Future<ServerSocket> bind2();

  TransportServer Function() getServer() {
    if (!inStreamList.containsKey(inStream)) {
      throw "wrong inStream tag.";
    }
    return inStreamList[inStream]!;
  }

  OutboundStruct doRoute(Link link) {
    if (!routeList.containsKey(route)) {
      throw 'There are no route named "$route"';
    }
    var outbound = routeList[route]!.match(link);
    var res = outboundsList[outbound]!();
    link.outboundStruct = res;
    print(
        "{${link.client.remoteAddress.address}:${link.client.remotePort}} [${link.inboundStruct.tag}:${link.inboundStruct.protocolName}] (${link.targetAddress}:${link.targetport}) --> [${res.tag}:${res.protocolName}]");
    return res;
  }
}
