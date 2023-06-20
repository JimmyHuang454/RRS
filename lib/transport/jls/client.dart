import 'dart:async';
import 'dart:typed_data';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/jls/jls.dart';
import 'package:proxy/transport/jls/tls/base.dart';
import 'package:proxy/utils/utils.dart';

class JLSClientHandler extends JLSHandler {
  bool isReceiveCert = false;

  JLSClientHandler(
      {required super.client,
      required super.jls,
      super.jlsTimeout,
      super.fallbackWebsite});

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
            checkRes.complete(true);
          }
        } else {
          isCheck = true;
          var parsedHello = ServerHello.parse(rawData: record);
          isValid = await jls.check(inputRemote: parsedHello);
          if (isValid) {
            client.add(ChangeSpec().build());
            isSendChangeSpec = true;
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
  List<int> content = [];

  final maxLen = 16384; // 2^14

  JLSSocket({required super.rrsSocket, required this.jlsHandler});

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

      var res = (await jlsHandler.jls.send(sendData)).build();
      rrsSocket.add(res);
    }
  }

  @override
  void listen(Future<void> Function(Uint8List event)? onData,
      {Future<void> Function(dynamic e, dynamic s)? onError,
      Future<void> Function()? onDone}) {
    rrsSocket.listen((data) async {
      devPrint(1);
      content += data;
      while (true) {
        var record = waitRecord();
        if (record.isEmpty) {
          return;
        }

        var realData = await jlsHandler.jls
            .receive(ApplicationData.parse(rawData: record));
        if (realData.isEmpty) {
          // auth did not pass.
          // TODO: unexpected msg(handle it like TLS1.3)
          return;
        }
        onData!(Uint8List.fromList(realData));
      }
    }, onDone: onDone, onError: onError);
  }
} //}}}
