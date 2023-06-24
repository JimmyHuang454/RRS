import 'dart:async';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/jls/client.dart';
import 'package:proxy/transport/jls/jls.dart';
import 'package:proxy/transport/jls/tls/base.dart';
import 'package:proxy/transport/server/base.dart';
import 'package:proxy/utils/utils.dart';

class JLSServerHandler extends JLSHandler {
  JLSServerHandler(
      {required super.client,
      required super.jls,
      super.jlsTimeout,
      super.fallbackWebsite});

  void close() {
    client.close();
    if (!checkRes.isCompleted) {
      checkRes.complete(false);
    }
  }

  @override
  Future<bool> secure() async {
    client.listen((date) async {
      content += date;
      var record = waitRecord();
      if (record.isEmpty) {
        return;
      }
      if (isCheck) {
        isReceiveChangeSpec = true;
        checkRes.complete(true);
      } else {
        isCheck = true;
        var parsedHello = ClientHello.parse(rawData: record);
        isValid = await jls.check(inputRemote: parsedHello);
        if (content.isNotEmpty || !isValid) {
          // it's len should not more than a clientHello.
          // restore record to forward proxy.
          content = record + content;
          checkRes.complete(false);
        } else {
          var serverHello = await jls.build();
          client.add(serverHello + ChangeSpec().build() + buildRandomCert());
          isSendChangeSpec = true;
        }
      }
    }, onDone: () async {
      close();
    }, onError: (e, s) async {
      close();
    });

    try {
      await checkRes.future.timeout(jlsTimeout);
    } catch (_) {}

    await client.clearListen();

    if (!isValid) {
      await forward();
      return false;
    }

    if (!isReceiveChangeSpec) {
      // ChangeSpec timeout.
      devPrint('not receive spec.');
      close();
      return false;
    }
    return true;
  }
}

class JLSServerSocket extends RRSServerSocketBase {
  JLSServerHandler Function(RRSSocket client) newJLSServer;

  JLSServerSocket({required super.rrsServerSocket, required this.newJLSServer});

  @override
  void listen(void Function(RRSSocket event)? onData,
      {Function(dynamic e, dynamic s)? onError, void Function()? onDone}) {
    rrsServerSocket.listen((client) async {
      var handler = newJLSServer(client);
      if (await handler.secure()) {
        onData!(JLSSocket(rrsSocket: client, jlsHandler: handler));
      }
    }, onDone: onDone, onError: onError);
  }
}
