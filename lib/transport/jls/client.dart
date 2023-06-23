import 'dart:async';
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
        if (record.isEmpty || client.isClosed) {
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

    if (client.isClosed) {
      return false;
    }

    if (!isReceiveCert) {
      closeAndThrow('timeout to get server cert');
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

  final maxLen = 16000; // 2^14
  List<int> content = [];

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
    if (len == 0) {
      return [];
    }
    return res;
  }

  @override
  Future<void> add(List<int> data) async {
    while (data.isNotEmpty) {
      List<int> res = [];
      if (data.length > maxLen) {
        res = data.sublist(0, maxLen);
        data = data.sublist(maxLen);
      } else {
        res = data;
        data = [];
      }
      // var temp = (await jlsHandler.jls.send(res)).build();
      var temp = ApplicationData(data: res).build();
      // var temp = buildAppData(res);
      super.add(temp);
    }
  }

  int currentLen = 0;

  Future<void> updateData(
      Uint8List data, Future<void> Function(Uint8List event)? onData) async {
    content += data;
    List<int> res = [];
    while (true) {
      var record = waitRecord();
      if (record.isEmpty) {
        break;
      }
      res = record.sublist(5);
      // var res =
      //     await jlsHandler.jls.receive(ApplicationData.parse(rawData: record));
      if (res.isEmpty) {
        // TODO: unexpected msg.
        devPrint('res.isEmpty');
        return;
      }
      await onData!(Uint8List.fromList(res));
    }
  }

  @override
  void listen(Future<void> Function(Uint8List event)? onData,
      {Future<void> Function(dynamic e, dynamic s)? onError,
      Future<void> Function()? onDone}) async {
    await updateData(Uint8List.fromList(jlsHandler.content),
        onData); // handle left msg in handshake.
    super.listen((data) async {
      await updateData(data, onData);
    }, onDone: onDone, onError: onError);
  }
} //}}}
