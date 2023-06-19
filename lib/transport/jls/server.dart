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

  bool isValid = false;
  bool isCheck = false;
  Completer checkRes = Completer();
  Duration? jlsTimeout;

  JLSServerSocket(
      {required super.rrsServerSocket,
      required this.jlsHandShakeSide,
      required this.jlsTimeout});

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

      var res = await jlsHandShakeSide!
          .check(inputRemote: ClientHello.parse(rawData: record));
      if (content.isNotEmpty || !res) {
        content = record + content;
        // its should not more len a clientHello.
        checkRes.complete(false);
      } else {
        checkRes.complete(true);
      }
    }, onDone: () async {
      client.close();
    }, onError: (e, s) async {
      client.close();
    });

    try {
      isValid = await checkRes.future.timeout(jlsTimeout!);
    } catch (_) {
      isValid = false;
    }
    await client.clearListen();
    if (!isValid) {
      // TODO:  pass to fallback website.
      return false;
    }
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
