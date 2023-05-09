import 'dart:async';
import 'dart:collection';
import 'package:async/async.dart';

import 'package:proxy/user.dart';
import 'package:proxy/utils/utils.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/obj_list.dart';

class ConnectionRes {
  int stats = 0; // 0 means not took, 1 means took, 2 means error.

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
    if (stats != 0) {
      return;
    }
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

  Future<RRSSocket> take() async {
    if (!isOK()) {
      throw error;
    }
    stats = 1;
    return rrsSocket;
  }
}

abstract class OutboundStruct {
  String protocolName;
  String protocolVersion;
  Map<String, dynamic> config;

  String tag = '';
  String outStreamTag = '';

  Address? outAddress;
  int? outPort;

  Traffic traffic = Traffic();

  int linkCount = 0;

  bool isMakingFood = false;

  bool isFastOpen = false;
  String outStrategy = 'default'; // OS default.
  int? queueLen;
  Duration? fastOpenTimeout;
  Queue<ConnectionRes>? fastOpenQueue;

  TransportClient? transportClient;

  OutboundStruct(
      {required this.protocolName,
      required this.protocolVersion,
      required this.config}) {
    tag = getValue(config, 'tag', '');
    outStreamTag = getValue(config, 'outStream', 'tcp');
    outStrategy = getValue(config, 'setting.strategy', 'default');

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

      var temp = getValue(config, 'fastopen.timeout', 0);
      if (temp == 0) {
        fastOpenTimeout = transportClient!.timeout;
      } else {
        fastOpenTimeout = Duration(seconds: temp);
      }
      fastOpenQueue = Queue<ConnectionRes>();
    }
  }

  Future<RRSSocket> realConnect() async {
    return await transportClient!.connect(outAddress!.address, outPort!);
  }

  Future<void> updateFastOpenQueue() async {
    if (!isFastOpen || isMakingFood) {
      return;
    }
    isMakingFood = true;

    var i = 0;
    while (fastOpenQueue!.length < queueLen! && i < queueLen!) {
      RRSSocket rrsSocket;
      try {
        rrsSocket = await realConnect();
      } catch (e) {
        logger.info(e);
        i += 1;
        continue;
      }
      fastOpenQueue!
          .add(ConnectionRes(rrsSocket: rrsSocket, timeout: fastOpenTimeout!));
    }

    isMakingFood = false;
  }

  Future<RRSSocket> connect(dynamic host, int port) async {
    if (!isFastOpen) {
      return await realConnect();
    }

    updateFastOpenQueue();
    devPrint(fastOpenQueue!.length);
    devPrint(isMakingFood);
    while (fastOpenQueue!.isNotEmpty) {
      var res = fastOpenQueue!.removeFirst();
      if (res.isOK()) {
        return res.take();
      }
    }
    return await transportClient!.connect(host, port);
  }

  Future<RRSSocket> newConnect(Link l) async {
    l.outAddress = l.targetAddress;
    l.outPort = l.targetport;

    // freeom outbound change outAddress with what inbound pass in.
    outAddress = l.targetAddress;
    outPort = l.targetport;
    return Connect(
        rrsSocket: await realConnect(), link: l, outboundStruct: this);
  }
}
