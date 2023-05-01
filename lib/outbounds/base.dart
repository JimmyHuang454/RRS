import 'dart:async';
import 'dart:collection';
import 'package:async/async.dart';

import 'package:proxy/user.dart';
import 'package:proxy/utils/utils.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/obj_list.dart';

class Dispacher {
  Queue<ConnectionRes>? resQueue;

  int queueLen;
  bool isMakingFood = false;

  Future<RRSSocket> Function() generator;

  Dispacher({required this.queueLen, required this.generator}) {
    resQueue = Queue<ConnectionRes>();
  }

  void makeFood() async {
    if (isMakingFood) {
      return;
    }
    isMakingFood = true;

    var i = 0;
    while (resQueue!.length < queueLen && i < queueLen) {
      i += 1;
      RRSSocket rrsSocket;
      try {
        rrsSocket = await generator();
      } catch (e) {
        logger.info(e);
        continue;
      }
      resQueue!.add(
          ConnectionRes(rrsSocket: rrsSocket, timeout: Duration(seconds: 2)));
    }

    isMakingFood = false;
  }

  Future<RRSSocket> eat() async {
    if (resQueue!.isNotEmpty) {
      var res = resQueue!.removeFirst();
      if (res.isOK()) {
        return res.take();
      }
    }
    makeFood();
    return await generator();
  }
}

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
  String outAddress = '';
  int outPort = 0;
  Traffic traffic = Traffic();

  int linkCount = 0;

  String realOutAddress = '';
  int realOutPort = 0;
  bool isMakingFood = false;

  bool isFastOpen = false;
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

      var temp = getValue(config, 'fastopen.timeout', 0);
      if (temp == 0) {
        fastOpenTimeout = transportClient!.timeout;
      } else {
        fastOpenTimeout = Duration(seconds: temp);
      }
      fastOpenQueue = Queue<ConnectionRes>();
    }
  }

  void updateFastOpenQueue() async {
    if (!isFastOpen || isMakingFood) {
      return;
    }
    isMakingFood = true;

    var i = 0;
    while (fastOpenQueue!.length < queueLen! && i < queueLen!) {
      i += 1;
      RRSSocket rrsSocket;
      try {
        rrsSocket = await transportClient!.connect(realOutAddress, realOutPort);
      } catch (e) {
        logger.info(e);
        continue;
      }
      fastOpenQueue!
          .add(ConnectionRes(rrsSocket: rrsSocket, timeout: fastOpenTimeout!));
    }

    isMakingFood = false;
  }

  Future<RRSSocket> connect(dynamic host, int port) async {
    if (!isFastOpen) {
      return await transportClient!.connect(host, port);
    }

    updateFastOpenQueue();
    while (fastOpenQueue!.isNotEmpty) {
      var res = fastOpenQueue!.removeFirst();
      if (res.isOK()) {
        return res.take();
      }
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
