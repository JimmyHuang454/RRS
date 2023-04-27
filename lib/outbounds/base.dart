import 'dart:async';
import 'package:async/async.dart';

import 'package:proxy/user.dart';
import 'package:proxy/utils/utils.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/obj_list.dart';

abstract class OutboundStruct {
  String protocolName;
  String protocolVersion;
  Map<String, dynamic> config;

  String tag = '';
  String outStreamTag = '';
  String outAddress = '';
  int outPort = 0;
  Traffic traffic = Traffic();

  int linkCount = 0;

  String realOutAddress = '';
  int realOutPort = 0;

  bool isFastOpen = false;
  int queueLen = 10;
  StreamQueue<RRSSocket>? fastOpenQueue;
  StreamController<RRSSocket>? fastOpenStream;

  TransportClient? transportClient;

  OutboundStruct(
      {required this.protocolName,
      required this.protocolVersion,
      required this.config}) {
    tag = getValue(config, 'tag', '');
    outStreamTag = getValue(config, 'outStream', 'tcp');
    outAddress = getValue(config, 'setting.address', '');
    outPort = getValue(config, 'setting.port', 0);

    realOutAddress = outAddress;
    realOutPort = outPort;

    if (!outStreamList.containsKey(outStreamTag) && protocolName != 'block') {
      throw 'wrong outStream named "$outStreamTag"';
    }

    if (protocolName != 'block') {
      transportClient = outStreamList[outStreamTag]!;
    }

    isFastOpen = getValue(config, 'fastopen.enable', false);
    if (isFastOpen) {
      fastOpenStream = StreamController<RRSSocket>();
      fastOpenQueue = StreamQueue<RRSSocket>(fastOpenStream!.stream);
    }
  }

  void updateFastOpenQueue() async {
    while (await fastOpenStream!.stream.length < queueLen) {
      var res = await transportClient!.connect(realOutAddress, realOutPort);
      fastOpenStream!.add(res);
    }
  }

  Future<RRSSocket> connect(dynamic host, int port) async {
    if (isFastOpen) {
      updateFastOpenQueue();
      return await fastOpenQueue!.next;
    }
    return await transportClient!.connect(host, port);
  }

  Future<RRSSocket> newConnect(Link l) async {
    realOutAddress = l.targetAddress!.address;
    realOutPort = l.targetport;
    return Connect(
        rrsSocket: await connect(realOutAddress, realOutPort),
        link: l,
        outboundStruct: this);
  }
}
