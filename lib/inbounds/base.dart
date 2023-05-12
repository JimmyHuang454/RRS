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

  Future<void> clientAdd(List<int> data) async {
    await client.add(data);
    if (user != null) {
      user!.addDownlink(data.length);
    }
    if (receivedState == 1 && firstReceivedTime != null) {
      receivedState = 2;
      firstReceivedTime!.stop();
    }
  }

  Future<void> serverAdd(List<int> data) async {
    if (server != null) {
      await server!.add(data);
    }
    if (user != null) {
      user!.addUplink(data.length);
    }
    if (firstReceivedTime == null) {
      firstReceivedTime = Stopwatch()..start();
      receivedState = 1;
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
    connectTime = Stopwatch()..start();

    try {
      server = await outboundStruct!.newConnect(this);
    } catch (e) {
      logger.info(
          'Error: ${buildLinkInfo()} (${routingTime.elapsed}) (${connectTime!.elapsed})');
      logger.info('(${e.toString()})');
      return false;
    }

    server!.listen((event) async {
      await clientAdd(event);
    }, onDone: () async {
      await closeClient();
    }, onError: (e, s) async {
      await closeClient();
    });

    server!.done!.then((value) async {
      await serverDone();
    }, onError: (e, s) async {
      await serverDone();
    });

    bindUser();
    outboundStruct!.traffic.activeLinkCount += 1;
    user!.traffic.activeLinkCount += 1;
    logger.info(
        'Created: ${buildLinkInfo()} (${routingTime.elapsed}) (${connectTime!.elapsed})');

    connectTime!.stop();
    return true;
  }

  Future<void> serverDone() async {
    user!.traffic.activeLinkCount -= 1;
    outboundStruct!.traffic.activeLinkCount -= 1;

    var time = '';
    if (firstReceivedTime != null) {
      time = firstReceivedTime!.elapsed.toString();
    } else {
      time = 'ERRO';
    }

    logger.info('Closed: ${buildLinkInfo()} ($time) ${buildLinkTrafficInfo()}');
    logger.info(
        '${outboundStruct!.tag}:${outboundStruct!.protocolName} ${buildOutTrafficInfo()}');
    createdTime.stop();
  }

  String buildInboudInfo() {
    return "[${inboundStruct.tag}:${inboundStruct.protocolName}] {${targetAddress!.address}:$targetport}";
  }

  String buildLinkTrafficInfo() {
    return "[${toMetric(server!.traffic.uplink, 2)}B/${toMetric(server!.traffic.downlink, 2)}B]";
  }

  String buildOutTrafficInfo() {
    return "[${toMetric(outboundStruct!.traffic.uplink, 2)}B/${toMetric(outboundStruct!.traffic.downlink, 2)}B] ${outboundStruct!.traffic.activeLinkCount}";
  }

  String buildOutboudInfo() {
    if (outboundStruct == null) {
      return '';
    }
    var temp = "[${outboundStruct!.tag}:${outboundStruct!.protocolName}]";
    if (outAddress != null && outPort != null) {
      return "$temp {${outAddress!.address}:${outPort!}}";
    }
    return "$temp {${outboundStruct!.outAddress!.address}:${outboundStruct!.outPort!}}";
  }

  String buildLinkInfo() {
    var temp =
        "${buildInboudInfo()} -<${outboundStruct!.transportClient!.protocolName}>-> ${buildOutboudInfo()}";
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
