import 'dart:async';
import 'dart:collection';

import 'package:cryptography/helpers.dart';
import 'package:proxy/handler.dart';
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

  Address? outAddress;
  int? outPort;

  Traffic traffic = Traffic();

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
    var outStreamTag = getValue(config, 'outStream', 'tcp');

    if (outStreamTag.runtimeType == String) {
      if (!outStreamList.containsKey(outStreamTag) && protocolName != 'block') {
        throw 'wrong outStream named "$outStreamTag"';
      }
      transportClient = outStreamList[outStreamTag]!;
    } else {
      transportClient =
          buildOutStream(randomBytesAsHexString(10), outStreamTag);
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
    if (!isFastOpen) {
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
    while (fastOpenQueue!.isNotEmpty) {
      var res = fastOpenQueue!.removeFirst();
      if (res.isOK()) {
        return res.take();
      }
    }
    return await realConnect();
  }

  Future<RRSSocket> newConnect(Link l) async {
    // freedom outbound change outAddress with what inbound pass in.
    outAddress = l.targetAddress;
    outPort = l.targetport;

    return Connect(
        rrsSocket: await connect(outAddress!.address, outPort!),
        link: l,
        outboundStruct: this);
  }
}
