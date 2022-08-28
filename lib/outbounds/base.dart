import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:proxy/utils/utils.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/obj_list.dart';

class Connect extends TransportClient {
  TransportClient transportClient;
  Link link;

  Connect({required this.transportClient, required this.link})
      : super(protocolName: 'connecting', config: {});

  @override
  Future<void> connect(host, int port) async {
    await transportClient.connect(host, port);
  }

  @override
  void add(List<int> data) {
    transportClient.add(data);
    link.traffic.uplink += data.length;
  }

  @override
  Future close() async {
    await transportClient.close();
  }

  @override
  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    transportClient.listen((data) {
      link.traffic.downlink += data.length;
      onData!(data);
    }, onDone: onDone, onError: onError);
  }

  @override
  Future get done => transportClient.done;
  @override
  InternetAddress get remoteAddress => transportClient.remoteAddress;
  @override
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

  Future<TransportClient> newConnect(Link l) async {
    var temp = newClient();
    await temp.connect(l.targetAddress.address, l.targetport);
    return temp;
  }
}
