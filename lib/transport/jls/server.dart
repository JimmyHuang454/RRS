import 'dart:async';
import 'dart:typed_data';

import 'package:cryptography/helpers.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/jls/client.dart';
import 'package:proxy/transport/jls/jls.dart';
import 'package:proxy/transport/jls/tls/base.dart';
import 'package:proxy/transport/server/base.dart';
import 'package:proxy/utils/utils.dart';

class JLSServerSocket extends RRSServerSocketBase {
  JLSHandShakeSide? jlsHandShakeSide;

  List<int> content = [];

  bool isFallback = false;
  bool isCheck = false;
  Completer checkRes = Completer();

  JLSServerSocket(
      {required super.rrsServerSocket, required this.jlsHandShakeSide});

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

  Future<bool> auth(RRSSocket client) async {
    client.listen((date) async {
      content += date;
      var record = waitRecord();
      if (record.isEmpty) {
        return;
      }

      isFallback = !(await jlsHandShakeSide!
          .check(inputRemote: ClientHello.parse(rawData: record)));
      if (content.isNotEmpty) {
        // its should not more len a clientHello.
        isFallback = true;
      }

      if (isFallback) {
        content = record + content;
      }
      checkRes.complete(isFallback);
    }, onDone: () async {
      client.close();
    }, onError: (e, s) async {
      client.close();
    });

    await checkRes.future;
    if (isFallback) {
      // TODO:  pass to fallback website.
      return false;
    }
    await client.clearListen();
    client.add(await jlsHandShakeSide!.build() +
        ChangeSpec().build() +
        buildRandomCert());
    return true;
  }

  List<int> buildRandomCert({int len = 32}) {
    return ApplicationData(data: randomBytes(len)).build();
  }

  @override
  void listen(void Function(RRSSocket event)? onData,
      {Function(dynamic e, dynamic s)? onError, void Function()? onDone}) {
    rrsServerSocket.listen((client) async {
      if (await auth(client)) {
        var res =
            JLSSocket(rrsSocket: client, jlsHandShakeSide: jlsHandShakeSide);
        onData!(res);
      }
    }, onDone: onDone, onError: onError);
  }
}
