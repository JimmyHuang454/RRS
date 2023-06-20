import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/jls/jls.dart';
import 'package:proxy/transport/jls/tls/base.dart';
import 'package:proxy/utils/utils.dart';

class JLSClientHandler extends JLSHandler {
  bool isReceiveCert = false;

  JLSClientHandler(
      {required super.client, required super.jls, super.jlsTimeout});

  void closeAndThrow(dynamic msg) {
    client.close();
    throw Exception('[JLS] $msg.');
  }

  @override
  Future<bool> secure() async {
    client.listen((data) async {
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
            isSendChangeSpec = true;
            await client.add(ChangeSpec().build());
            checkRes.complete(true);
          }
        } else {
          isCheck = true;
          var parsedHello = ServerHello.parse(rawData: record);
          isValid = await jls.check(inputRemote: parsedHello);
          if (isValid) {
          } else {
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

    var clientHello = await jls.build();
    client.add(clientHello);

    try {
      await checkRes.future.timeout(jlsTimeout);
    } catch (_) {}

    await client.clearListen();

    if (!isReceiveCert) {
      closeAndThrow('timeout to get server cert.');
      return false;
    }

    if (!isValid) {
      // TODO: handle it like normal tls1.3 client.
      closeAndThrow('wrong server response or timeout.');
      return false;
    }
    return true;
  }
}

class JLSSocket extends RRSSocketBase {
  //{{{

  JLSHandler jlsHandler;

  final maxLen = 16384; // 2^14

  JLSSocket({required super.rrsSocket, required this.jlsHandler});

  @override
  Future<void> add(List<int> data) async {
    List<int> sendData = [];
    while (data.isNotEmpty) {
      int len = data.length;
      if (len > maxLen) {
        len = maxLen;
      }
      sendData = (await jlsHandler.jls.send(data.sublist(0, len))).build();
      rrsSocket.add(sendData);
      data = data.sublist(len);
    }
  }

  Future<void> updateData(
      Uint8List data, Future<void> Function(Uint8List event)? onData) async {
    jlsHandler.content += data;
    while (true) {
      var record = jlsHandler.waitRecord();
      if (record.isEmpty) {
        return;
      }
      var res =
          await jlsHandler.jls.receive(ApplicationData.parse(rawData: record));
      if (res.isEmpty) {
        // TODO: unexpected msg.
        return;
      }
      onData!(Uint8List.fromList(res));
    }
  }

  @override
  void listen(Future<void> Function(Uint8List event)? onData,
      {Future<void> Function(dynamic e, dynamic s)? onError,
      Future<void> Function()? onDone}) async {
    await updateData(
        Uint8List.fromList([]), onData); // handle left msg in handshake.
    rrsSocket.listen((data) async {
      await updateData(data, onData);
    }, onDone: onDone, onError: onError);
  }
} //}}}
