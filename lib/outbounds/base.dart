import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:proxy/user.dart';
import 'package:proxy/utils/utils.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/obj_list.dart';

class Connect extends TransportClient {
  TransportClient transportClient;
  OutboundStruct outboundStruct;
  Link link;
  late RawDatagramSocket udpClient;

  Connect(
      {required this.transportClient,
      required this.link,
      required this.outboundStruct})
      : super(protocolName: 'connecting', config: {});

  @override
  Future<void> connect(host, int port) async {
    if (link.streamType == 'TCP') {
      await transportClient.connect(host, port);
    } else {
      udpClient = await RawDatagramSocket.bind(host, port);
    }
  }

  @override
  void add(List<int> data) {
    if (link.streamType == 'TCP') {
      transportClient.add(data);
    } else {
      udpClient.send(
          data, InternetAddress(link.targetAddress.address), link.targetport);
    }
    outboundStruct.traffic.uplink += data.length;
    link.traffic.uplink += data.length;
  }

  @override
  Future close() async {
    if (link.streamType == 'TCP') {
      await transportClient.close();
    } else {
      udpClient.close();
    }
  }

  @override
  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    if (link.streamType == 'TCP') {
      transportClient.listen((data) {
        link.traffic.downlink += data.length;
        outboundStruct.traffic.downlink += data.length;
        onData!(data);
      }, onDone: onDone, onError: onError);
    } else {
      var temp = udpClient.listen((event) {
        Datagram? d = udpClient.receive();
        if (d == null) {
          return;
        }
        var data = d.data;
        link.traffic.downlink += data.length;
        outboundStruct.traffic.downlink += data.length;
        onData!(data);
      }, onError: onError, onDone: onDone, cancelOnError: true);
      streamSubscription.add(temp);
    }
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
  Map<String, dynamic> config;

  String tag = '';
  String outStreamTag = '';
  String outAddress = '';
  int outPort = 0;
  Traffic traffic = Traffic();

  String realOutAddress = '';
  int realOutPort = 0;

  OutboundStruct(
      {required this.protocolName,
      required this.protocolVersion,
      required this.config}) {
    tag = getValue(config, 'tag', '');
    outStreamTag = getValue(config, 'outStream', '');
    outAddress = getValue(config, 'setting.address', '');
    outPort = getValue(config, 'setting.port', 0);

    realOutAddress = outAddress;
    realOutPort = outPort;
  }

  TransportClient newClient() {
    if (!outStreamList.containsKey(outStreamTag)) {
      throw "wrong outStreamTag.";
    }
    return outStreamList[outStreamTag]!();
  }

  Future<TransportClient> newConnect(Link l) async {
    realOutAddress = l.targetAddress.address;
    realOutPort = l.targetport;
    var temp =
        Connect(transportClient: newClient(), link: l, outboundStruct: this);
    await temp.connect(realOutAddress, realOutPort);
    return temp;
  }
}
