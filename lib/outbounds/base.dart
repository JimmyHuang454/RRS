import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:proxy/utils/utils.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/obj_list.dart';

class Connect {
  TransportClient transportClient;
  OutboundStruct outboundStruct;
  Link link;
  String realOutAddress;
  int realOutPort;

  Connect(
      {required this.transportClient,
      required this.outboundStruct,
      required this.link,
      required this.realOutAddress,
      required this.realOutPort});

  Future<void> connect() async {
    await transportClient.connect(realOutAddress, realOutPort);
  }

  void add(List<int> data) {
    outboundStruct.upLinkByte += data.length;
    transportClient.add(data);
  }

  Future close() {
    return transportClient.close();
  }

  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    transportClient.listen((data) {
      outboundStruct.downLinkByte += data.length;
      onData!(data);
    }, onError: onError, onDone: onDone);
  }

  Future get done => transportClient.done;
  InternetAddress get remoteAddress => transportClient.remoteAddress;
  int get remotePort => transportClient.remotePort;
}

abstract class OutboundStruct {
  String protocolName;
  String protocolVersion;
  late String tag;

  int upLinkByte = 0;
  int downLinkByte = 0;
  late String outAddress;
  late int outPort;
  late String outStreamTag;

  Map<String, dynamic> config;

  OutboundStruct(
      {required this.protocolName,
      required this.protocolVersion,
      required this.config}) {
    tag = config['tag'];
    outStreamTag = config['outStream'];
    outAddress = getValue(config, 'setting.address', '');
    outPort = getValue(config, 'setting.port', 0);
  }

  TransportClient newClient() {
    if (!outStreamList.containsKey(outStreamTag)) {
      throw "wrong outStreamTag.";
    }
    return outStreamList[outStreamTag]!();
  }

  Future<Connect> newConnect(Link l) async {
    return Connect(
        transportClient: newClient(),
        outboundStruct: this,
        link: l,
        realOutAddress: l.targetAddress.address,
        realOutPort: l.targetport);
  }
}
