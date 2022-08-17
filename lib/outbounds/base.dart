import 'dart:io';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/obj_list.dart';
import 'package:proxy/utils/utils.dart';

abstract class OutboundStruct {
  String protocolName;
  String protocolVersion;
  late String tag;
  late String outStream;

  Map<String, dynamic> config;

  bool useFakeDNS = false;

  OutboundStruct(
      {required this.protocolName,
      required this.protocolVersion,
      required this.config}) {
    tag = config['tag'];
    outStream = config['outStream'];
  }

  TransportClient Function() getClient() {
    if (!outStreamList.containsKey(outStream)) {
      throw "wrong outStream tag.";
    }
    return outStreamList[outStream]!;
  }

  Future<Socket> connect(Link link);
}
