import 'dart:io';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/obj_list.dart';
import 'package:proxy/utils/utils.dart';

abstract class OutboundStruct {
  String protocolName;
  String protocolVersion;
  late String tag;
  late String clientTag;

  Map<String, dynamic> config;

  bool useFakeDNS = false;

  OutboundStruct(
      {required this.protocolName,
      required this.protocolVersion,
      required this.config}) {
    tag = config['tag'];
    clientTag = config['clientTag'];
  }

  TransportClient Function() getClient() {
    if (!outStreamList.containsKey(clientTag)) {
      throw "wrong outStream tag.";
    }
    return outStreamList[clientTag]!;
  }

  Future<Socket> connect(Link link);
}
