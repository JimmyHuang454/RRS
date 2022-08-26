import 'dart:io';

import 'package:proxy/outbounds/base.dart';
import 'package:proxy/transport/server/base.dart';
import 'package:proxy/obj_list.dart';
import 'package:proxy/utils/utils.dart';

class Link {
  Socket client; // in

  late Uri targetUri; // if it's a HTTP request.
  String method = 'GET';
  int cmd = 0;

  late Address targetAddress;
  int targetport = 0;
  String streamType = 'TCP'; // TCP | UDP

  String protocolVersion = '';
  List<int> userID = [];
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
    } catch (e) {
      // devPrint(e);
    }
    try {
      outboundStruct.close();
    } catch (e) {
      // devPrint(e);
    }
    try {
      devPrint('${targetAddress.address} closed');
    } catch (_) {}
  }

  void clientAdd(List<int> data) {
    try {
      client.add(data);
    } catch (e) {
      // devPrint(e);
    }
  }

  void serverAdd(List<int> data) {
    try {
      outboundStruct.add(data);
    } catch (e) {
      devPrint(e);
    }
  }

  Future<bool> bindServer() async {
    outboundStruct = await inboundStruct.doRoute(this);
    try {
      await outboundStruct.connect(this);
    } catch (e) {
      print(e);
      closeAll();
      return false;
    }

    outboundStruct.listen((event) {
      clientAdd(event);
    }, onDone: () {
      closeAll();
    }, onError: (e) {
      closeAll();
    });

    outboundStruct.done.then((value) {
      closeAll();
    }, onError: (e) {
      closeAll();
    });
    return true;
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

  Future<OutboundStruct> doRoute(Link link) async {
    if (!routeList.containsKey(route)) {
      throw 'There are no route named "$route"';
    }
    var outbound = await routeList[route]!.match(link);
    var res = outboundsList[outbound]!();
    link.outboundStruct = res;
    try {
      print(
          "{${link.client.remoteAddress.address}:${link.client.remotePort}} [${link.inboundStruct.tag}:${link.inboundStruct.protocolName}] (${link.targetAddress.address}:${link.targetport}) --> [${res.tag}:${res.protocolName}]");
    } catch (e) {
      print(e);
    }
    return res;
  }
}
