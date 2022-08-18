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

  Link({required this.client, required this.inboundStruct});
}

abstract class InboundStruct {
  String protocolName;
  String protocolVersion;
  late String tag;
  late String inStream;
  late String routeTag;

  Map<String, dynamic> config;

  int totalClient = 0;

  InboundStruct(
      {required this.protocolName,
      required this.protocolVersion,
      required this.config}) {
    tag = config['tag'];
    inStream = getValue(config, 'inStream', '');
    routeTag = getValue(config, 'routeTag', '');

    if (inStream == '' || routeTag == '') {
      throw 'inStream and routeTag can NOT be null.';
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
    if (!routeList.containsKey(routeTag)) {
      throw 'There are no route named "$routeTag"';
    }
    var outTag = routeList[routeTag]!.match(link);
    var res = outboundsList[outTag]!;
    link.outboundStruct = res;
    return res;
  }
}
