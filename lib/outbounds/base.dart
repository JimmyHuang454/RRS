import 'dart:async';
import 'package:async/async.dart';

import 'package:proxy/user.dart';
import 'package:proxy/utils/utils.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/obj_list.dart';

class ConnectionRes {
  int stats = 0; // means ok.

  Duration timeout;
  dynamic error, stack;
  RRSSocket rrsSocket;

  ConnectionRes({required this.timeout, required this.rrsSocket}) {
    rrsSocket.done!.then((value) async {
      await expire('server closed.', '');
    }, onError: (e, s) async {
      await expire(e, s);
    });

    Future.delayed(timeout).then(
      (value) async {
        await expire('timeout', '');
      },
    );
  }

  // Connection can not be used anymore.
  Future<void> expire(dynamic e, dynamic s) async {
    stats = 2;
    error = e;
    stack = s;
    await rrsSocket.close();
  }

  // Connection may be timeout or closed by server, so we check before we actually use it.
  bool isOK() {
    if (stats != 0) {
      return false;
    }
    return true;
  }

  RRSSocket take() {
    if (!isOK()) {
      throw error;
    }
    return rrsSocket;
  }
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

  int linkCount = 0;

  String realOutAddress = '';
  int realOutPort = 0;

  bool isFastOpen = false;
  int? queueLen;
  int waittingQueueLen = 0;
  Duration? fastOpenTimeout;
  StreamQueue<ConnectionRes>? fastOpenQueue;
  StreamController<ConnectionRes>? fastOpenStream;

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

    if (protocolName != 'freedom' && protocolName != 'block') {
      isFastOpen = getValue(config, 'fastopen.enable', false);
    }

    if (isFastOpen) {
      queueLen = getValue(config, 'fastopen.size', 15);
      fastOpenTimeout =
          Duration(seconds: getValue(config, 'fastopen.timeout', 40));

      fastOpenStream = StreamController<ConnectionRes>.broadcast(sync: true);
      fastOpenQueue = StreamQueue<ConnectionRes>(fastOpenStream!.stream);
    }
  }

  void updateFastOpenQueue() async {
    while (waittingQueueLen < queueLen!) {
      var res = await transportClient!.connect(realOutAddress, realOutPort);
      fastOpenStream!
          .add(ConnectionRes(timeout: fastOpenTimeout!, rrsSocket: res));
      waittingQueueLen += 1;
    }
  }

  Future<RRSSocket> connect(dynamic host, int port) async {
    if (!isFastOpen) {
      return await transportClient!.connect(host, port);
    }

    updateFastOpenQueue();
    ConnectionRes connectionRes;
    while (true) {
      connectionRes =
          await fastOpenQueue!.next.timeout(transportClient!.timeout!);
      waittingQueueLen -= 1;
      if (connectionRes.isOK()) {
        return connectionRes.take();
      }
    }
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
