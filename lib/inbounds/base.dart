import 'dart:io';

import 'package:proxy/outbounds/base.dart';
import 'package:proxy/transport/server/base.dart';
import 'package:proxy/obj_list.dart';
import 'package:proxy/utils/utils.dart';

class Link {
  Socket client; // in
  late Connect server; // out

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

  Stopwatch createdTime = Stopwatch()..start();

  Link({required this.client, required this.inboundStruct});

  Future<void> closeAll() async {
    try {
      await client.close();
    } catch (e) {
      // devPrint(e);
    }
    try {
      await server.close();
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
      server.add(data);
    } catch (e) {
      devPrint(e);
    }
  }

  Future<bool> bindServer() async {
    outboundStruct = await inboundStruct.doRoute(this);
    try {
      server = await outboundStruct.newConnect(this);
      await server.connect();
    } catch (e) {
      print(e);
      await closeAll();
      return false;
    }

    try {
      print(
          "{${client.remoteAddress.address}:${client.remotePort}} [${inboundStruct.tag}:${inboundStruct.protocolName}] (${targetAddress.address}:$targetport) --> {${server.realOutAddress}:${server.realOutPort}} [${outboundStruct.tag}:${outboundStruct.protocolName}] (${createdTime.elapsed})");
    } catch (e) {
      print(e);
    }
    print('${toMetric(outboundStruct.upLinkByte)}B/${toMetric(outboundStruct.downLinkByte)}B');

    server.listen((event) {
      clientAdd(event);
    }, onDone: () async {
      // await closeAll();
    }, onError: (e) async {
      // await closeAll();
    });

    server.done.then((value) async {
      await closeAll();
    }, onError: (e) async {
      await closeAll();
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
    link.outboundStruct = outboundsList[outbound]!;
    return link.outboundStruct;
  }
}
