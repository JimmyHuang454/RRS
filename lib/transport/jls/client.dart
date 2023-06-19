import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/jls/format.dart';
import 'package:proxy/transport/jls/jls.dart';
import 'package:proxy/transport/jls/tls/base.dart';
import 'package:proxy/utils/utils.dart';

class JLSSocket extends RRSSocketBase {
  //{{{
  JLSHandShakeSide? jlsHandShakeSide;

  bool isCheck = false;
  List<int> content = [];

  bool isValid = false;
  bool isReceiveChangeSpec = false;
  bool isReceiveCert = false;
  bool isSendChangeSpec = false;
  Completer checkRes = Completer();

  final maxLen = 16384; // 2^14

  JLSSocket({required super.rrsSocket, required this.jlsHandShakeSide});

  void closeAndThrow(dynamic msg) {
    rrsSocket.close();
    throw Exception('[JLS] $msg.');
  }

  List<int> waitRecord() {
    if (content.length < 5) {
      return [];
    }
    ByteData byteData =
        ByteData.sublistView(Uint8List.fromList(content.sublist(3, 5)));
    var len = byteData.getUint16(0, Endian.big);
    if (content.length - 5 < len) {
      return [];
    }
    var res = content.sublist(0, 5 + len);
    content = content.sublist(5 + len);
    return res;
  }

  Future<void> secure(Duration timeout) async {
    rrsSocket.listen((data) async {
      content += data;
      while (true) {
        var record = waitRecord();
        if (record.isEmpty) {
          return;
        }

        if (isCheck) {
          if (!isReceiveChangeSpec) {
            isReceiveChangeSpec = true;
          } else if (!isReceiveCert) {
            isReceiveCert = true;
            if (content.isNotEmpty) {
              closeAndThrow('unexpected msg.');
            }
            checkRes.complete(true);
          }
        } else {
          isCheck = true;
          if (!await jlsHandShakeSide!
              .check(inputRemote: ServerHello.parse(rawData: record))) {
            content = record + content; // restore all data to forward proxy.
            checkRes.complete(false);
            break;
          }
        }
      }
    }, onDone: () async {
      closeAndThrow('unexpected closed.');
    }, onError: (e, s) async {
      closeAndThrow(e);
    });

    var clientHello = await jlsHandShakeSide!.build();
    rrsSocket.add(clientHello);

    try {
      isValid = await checkRes.future.timeout(timeout);
    } catch (_) {
      isValid = false;
    }

    await rrsSocket.clearListen();
    if (!isValid) {
      // TODO: handle it like normal tls1.3 client.
      closeAndThrow('wrong server response or timetou.');
    }
  }

  @override
  Future<void> add(List<int> data) async {
    List<int> sendData = [];
    while (data.isNotEmpty) {
      if (data.length > maxLen) {
        sendData = data.sublist(0, maxLen);
        data = data.sublist(maxLen);
      } else {
        sendData = data;
        data = [];
      }

      var res = (await jlsHandShakeSide!.send(sendData)).build();
      if (!isSendChangeSpec && jlsHandShakeSide!.local!.isClient()) {
        isSendChangeSpec = true;
        res = ChangeSpec().build() + res;
      }
      rrsSocket.add(res);
    }
  }

  @override
  void listen(Future<void> Function(Uint8List event)? onData,
      {Future<void> Function(dynamic e, dynamic s)? onError,
      Future<void> Function()? onDone}) {
    rrsSocket.listen((data) async {
      content += data;
      while (true) {
        var record = waitRecord();
        if (record.isEmpty) {
          return;
        }

        if (!isReceiveChangeSpec) {
          isReceiveChangeSpec = true;
          continue;
        }

        if (!isReceiveCert && jlsHandShakeSide!.local!.isClient()) {
          isReceiveCert = true;
          continue;
        }

        var realData = await jlsHandShakeSide!
            .receive(ApplicationData.parse(rawData: record));
        if (realData.isEmpty) {
          // TODO: unexpected msg.
          return;
        }
        onData!(Uint8List.fromList(realData));
      }
    }, onDone: onDone, onError: onError);
  }
} //}}}
