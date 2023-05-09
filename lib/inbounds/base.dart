import 'dart:async';

import 'package:proxy/outbounds/base.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/obj_list.dart';
import 'package:proxy/transport/server/base.dart';
import 'package:proxy/user.dart';
import 'package:proxy/utils/utils.dart';
import 'package:proxy/utils/const.dart';

class Link {
  RRSSocket client; // in
  RRSSocket? server; // out
  InboundStruct inboundStruct;
  OutboundStruct? outboundStruct; // assign after routing.

  Uri? targetUri; // if it's a HTTP request.
  bool isHTTPRequest = false;
  bool isBitcont = false;
  String method = 'GET';
  CmdType cmd = CmdType.connect;

  Address? outAddress; // real proxy address of targetAddress.
  int? outPort = 0;

  Address? targetAddress;
  int? targetport;
  String targetIP =
      ''; // if targetAddress is domain, targetIP is the result of lookup.

  StreamType streamType = StreamType.tcp;

  List<int> userID = [];
  User? user;

  int timeout = 100;
  bool isValidRequest = false;

  Stopwatch createdTime = Stopwatch()..start();
  Stopwatch routingTime = Stopwatch()..start();
  Stopwatch? firstReceivedTime;
  Stopwatch? connectTime;
  int receivedState = 0;

  Link({required this.client, required this.inboundStruct});

  Future<void> closeClient() async {
    await client.close();
  }

  Future<void> closeServer() async {
    if (server != null) {
      await server!.close();
    }
  }

  Future<void> closeAll() async {
    await closeServer();
    await closeClient();
  }

  void clientAdd(List<int> data) {
    client.add(data);
    if (receivedState == 1 && firstReceivedTime != null) {
      receivedState = 2;
      firstReceivedTime!.stop();
    }
    if (user != null) {
      user!.addDownlink(data.length);
    }
  }

  void serverAdd(List<int> data) {
    if (server != null) {
      server!.add(data);
    }
    if (firstReceivedTime == null) {
      firstReceivedTime = Stopwatch()..start();
      receivedState = 1;
    }
    if (user != null) {
      user!.addUplink(data.length);
    }
  }

  void bindUser() {
    if (userID.isEmpty) {
      userID = [0];
    }

    var userIDStr = userID.toString();

    if (userList.containsKey(userIDStr)) {
      user = userList[userIDStr]!;
    } else {
      user = User();
      userList[userIDStr] = user!;
    }
  }

  Future<bool> bindServer() async {
    outboundStruct = await inboundStruct.doRoute(this);
    try {
      connectTime = Stopwatch()..start();
      server = await outboundStruct!.newConnect(this);
    } catch (e) {
      logger.info(e);
      await closeAll();
      return false;
    }

    bindUser();

    server!.listen((event) {
      clientAdd(event);
    }, onDone: () async {
      await closeAll();
    }, onError: (e, s) async {
      await closeAll();
    });

    server!.done!.then((value) async {
      await serverDone();
    }, onError: (e, s) async {
      await serverDone();
    });

    outboundStruct!.linkCount += 1;
    user!.linkCount += 1;
    logger.info(
        'Created: ${buildLinkInfo()} (${routingTime.elapsed}) (${connectTime!.elapsed})');

    connectTime!.stop();
    return true;
  }

  Future<void> serverDone() async {
    user!.linkCount -= 1;
    outboundStruct!.linkCount -= 1;

    var time = '';
    if (firstReceivedTime != null) {
      time = firstReceivedTime!.elapsed.toString();
    } else {
      time = 'ERRO';
    }

    logger.info(
        'Closed: ${buildLinkInfo()} ($time) [${toMetric(server!.traffic.uplink, 2)}B/${toMetric(server!.traffic.downlink, 2)}B]');
    logger.info(
        '${outboundStruct!.tag}:${outboundStruct!.protocolName} [${toMetric(outboundStruct!.traffic.uplink, 2)}B/${toMetric(outboundStruct!.traffic.downlink, 2)}B] ${outboundStruct!.linkCount}');
    createdTime.stop();
  }

  String buildLinkInfo() {
    var temp =
        " [${inboundStruct.tag}:${inboundStruct.protocolName}] {${targetAddress!.address}:$targetport} -<${outboundStruct!.transportClient!.protocolName}>-> [${outboundStruct!.tag}:${outboundStruct!.protocolName}] {${outAddress!.address}:${outPort!}}";
    return '$temp (${createdTime.elapsed})';
  }
}

abstract class InboundStruct {
  String protocolName;
  String protocolVersion;

  int upLinkByte = 0;
  int downLinkByte = 0;

  late String inAddress;
  late int inPort;
  late String tag;
  late String inStream;
  late String route;

  Map<String, dynamic> config;

  int totalClient = 0;
  TransportServer? transportServer;

  InboundStruct(
      {required this.protocolName,
      required this.protocolVersion,
      required this.config}) {
    tag = config['tag'];
    inStream = getValue(config, 'inStream', 'tcp');
    route = getValue(config, 'route', '');
    inAddress = getValue(config, 'setting.address', '');
    inPort = getValue(config, 'setting.port', 0);

    if (inStream == '' || route == '') {
      throw 'inStream and route can NOT be null.';
    }

    if (!routeList.containsKey(route)) {
      throw 'wrong route tag named "$route"';
    }

    if (!inStreamList.containsKey(inStream)) {
      throw 'wrong inStream tag named "$inStream"';
    }
    transportServer = inStreamList[inStream]!;
  }

  Future<void> bind();

  Future<OutboundStruct> doRoute(Link link) async {
    if (!routeList.containsKey(route)) {
      throw 'There are no route named "$route"';
    }
    var outbound = await routeList[route]!.match(link);
    link.outboundStruct = outboundsList[outbound]!;
    link.routingTime.stop();
    return link.outboundStruct!;
  }
}
