import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:proxy/utils/utils.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/obj_list.dart';

abstract class OutboundStruct {
  String protocolName;
  String protocolVersion;
  late String tag;

  late String outAddress;
  late int outPort;
  late String outStream;
  late TransportClient transportClient;

  Map<String, dynamic> config;

  OutboundStruct(
      {required this.protocolName,
      required this.protocolVersion,
      required this.config}) {
    tag = config['tag'];
    outStream = config['outStream'];
    outAddress = getValue(config, 'setting.address', '');
    outPort = getValue(config, 'setting.port', 0);

    transportClient = getClient()();
  }

  TransportClient Function() getClient() {
    if (!outStreamList.containsKey(outStream)) {
      throw "wrong outStream tag.";
    }
    return outStreamList[outStream]!;
  }

  Future<void> connect(Link l) async {
    await transportClient.connect(l.targetAddress.address, l.targetport);
  }

  void add(List<int> data) {
    transportClient.add(data);
  }

  Future close() {
    return transportClient.close();
  }

  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    transportClient.listen(onData, onError: onError, onDone: onDone);
  }

  Future get done => transportClient.done;
  InternetAddress get remoteAddress => transportClient.remoteAddress;
  int get remotePort => transportClient.remotePort;
}
