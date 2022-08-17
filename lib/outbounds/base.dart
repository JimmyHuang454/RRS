import 'dart:io';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/obj_list.dart';

abstract class OutboundStruct {
  String protocolName;
  String protocolVersion;
  String tag;
  String clientTag;

  Map<String, dynamic> config;

  bool useFakeDNS = false;

  OutboundStruct(
      {required this.tag,
      required this.protocolName,
      required this.protocolVersion,
      required this.clientTag,
      required this.config});

  TransportClient Function() getClient() {
    if (!outStreamList.containsKey(clientTag)) {
      throw "wrong outStream tag.";
    }
    return outStreamList[clientTag]!;
  }

  Future<Socket> connect(Link link);
}
