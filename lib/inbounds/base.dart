import 'dart:async';

import 'package:proxy/outbounds/base.dart';
import 'package:proxy/transport/mux.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/obj_list.dart';
import 'package:proxy/user.dart';
import 'package:proxy/utils/utils.dart';

class Link {
  RRSSocket client; // in
  RRSSocket? server; // out

  Uri? targetUri; // if it's a HTTP request.
  String method = 'GET';
  int cmd = 0;

  Address? targetAddress;
  String targetIP = '';
  int targetport = 0;
  String streamType = 'TCP'; // TCP | UDP
  bool ipUseCache = false;

  String protocolVersion = '';
  List<int> userID = [];
  bool isHTTPRequest = false;
  bool isBitcont = false;
  int timeout = 100;
  bool isValidRequest = false;
  bool isClosedAll = false;
  User? user;

  InboundStruct inboundStruct;
  OutboundStruct? outboundStruct; // assign after routing.

  Stopwatch createdTime = Stopwatch()..start();
  Stopwatch routingTime = Stopwatch()..start();
  Stopwatch? connectTime;
  String linkInfo = '';

  Link({required this.client, required this.inboundStruct});

  void closeClient() {
    client.close();
  }

  void closeServer() {
    if (server != null) {
      server!.close();
    }
  }

  void closeAll() {
    closeServer();
    closeClient();
  }

  void clientAdd(List<int> data) {
    client.add(data);
    user!.addDownlink(data.length);
  }

  void serverAdd(List<int> data) {
    if (server != null) {
      server!.add(data);
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
      closeAll();
      return false;
    }

    bindUser();

    server!.listen((event) {
      clientAdd(event);
    }, onDone: () {
      closeAll();
    }, onError: (e) {
      closeAll();
    });

    connectTime!.stop();
    outboundStruct!.linkCount += 1;
    user!.linkCount += 1;

    logger.info(
        'Created: ${buildLinkInfo()} (${routingTime.elapsed}) (${connectTime!.elapsed})');
    return true;
  }

  void serverDone() {
    user!.linkCount -= 1;
    outboundStruct!.linkCount -= 1;

    logger.info(
        'Closed: ${buildLinkInfo()} [${toMetric(server!.traffic.uplink, 2)}B/${toMetric(server!.traffic.downlink, 2)}B]');
    logger.info(
        '${outboundStruct!.tag}:${outboundStruct!.protocolName} [${toMetric(outboundStruct!.traffic.uplink, 2)}B/${toMetric(outboundStruct!.traffic.downlink, 2)}B] ${outboundStruct!.linkCount}');
  }

  String buildLinkInfo() {
    if (linkInfo == '') {
      var isMux = '';
      if (outboundStruct!.getClient().transportClient.isMux) {
        isMux = ':mux';
      }
      linkInfo =
          " [${inboundStruct.tag}:${inboundStruct.protocolName}] {${targetAddress!.address}:$targetport} -<${outboundStruct!.getClient().transportClient.protocolName}$isMux>-> [${outboundStruct!.tag}:${outboundStruct!.protocolName}] {${outboundStruct!.realOutAddress}:${outboundStruct!.realOutPort}}";
    }
    return '$linkInfo (${createdTime.elapsed})';
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
  late MuxServer _muxServer;

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

    if (!inStreamList.containsKey(inStream)) {
      throw 'wrong inStream tag named "$inStream"';
    }
    _muxServer = inStreamList[inStream]!;
  }

  Future<void> bind();

  MuxServer getServer() {
    return _muxServer;
  }

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
