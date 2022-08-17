import 'dart:io';

import 'package:proxy/outbounds/base.dart';
import 'package:proxy/transport/server/base.dart';
import 'package:proxy/obj_list.dart';

class Link {
  Socket client; // in
  late Socket server; // out

  late Uri targetUri; // if it's a HTTP request.
  String method = 'GET';

  String typeOfAddress = 'domain'; // domain | ipv4 | ipv6
  String targetAddress = '';
  String streamType = 'TCP'; // TCP | UDP

  String userID = 'none';
  bool isTLS = false;
  bool isHTTPRequest = false;
  bool isBitcont = false;
  int timeout = 100;
  bool isValidRequest = false;

  InboundStruct inboundStruct;
  late OutboundStruct outboundStruct; // assign after routing.

  Link(this.client, this.inboundStruct);
}

class InboundStruct {
  String protocolName;
  String protocolVersion;
  late String tag;
  late String serverTag;
  late String routeTag;

  Map<String, dynamic> config;

  int totalClient = 0;

  InboundStruct(
      {required this.protocolName,
      required this.protocolVersion,
      required this.config}) {
    tag = config['tag'];
    serverTag = config['serverTag'];
    routeTag = config['routeTag'];
  }

  TransportServer Function() getServer() {
    if (!inStreamList.containsKey(serverTag)) {
      throw "wrong inStream tag.";
    }
    return inStreamList[serverTag]!;
  }
}
