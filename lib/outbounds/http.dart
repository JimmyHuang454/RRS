import 'dart:async';
import 'dart:typed_data';
import 'package:async/async.dart';

import 'package:proxy/utils/utils.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/outbounds/base.dart';

class HTTPOut extends OutboundStruct {
  String userAccount = '';
  String userPassword = '';
  bool isBuildConnection = false;
  late Link link;

  HTTPOut({required super.config})
      : super(protocolName: 'http', protocolVersion: '1.1') {
    userAccount = getValue(config, 'setting.account', '');
    userPassword = getValue(config, 'setting.password', '');

    if (outAddress == '' || outPort == 0) {
      throw '"address" and "port" can not be empty in http setting.';
    }
  }

  List<int> _buildConnectionRequest() {
    return '${link.method} ${link.targetUri.toString()} ${link.protocolVersion}\r\n\r\n'
        .codeUnits;
  }

  @override
  Future<void> connect(Link l) async {
    link = l;
    var conn = await transportClient.connect(outAddress, outPort);

    if (link.method == 'CONNECT') {
      var streamController = StreamController<int>();
      var w = StreamQueue<int>(streamController.stream);
      super.listen((data) {
        var pos = indexOfElements(data, '\r\n\r\n'.codeUnits);
        if (pos == -1) {
          streamController.add(0); // failed.
        } else {
          streamController.add(1); // created
        }
      }, onError: (e) {
        streamController.add(0);
      });
      super.add(_buildConnectionRequest());
      var res = await w.next;
      await w.cancel();
      await streamController.close();
      transportClient.clearListen();

      if (res != 1) {
        await super.close();
        throw 'failed to build http tunnel.';
      }
      isBuildConnection = true;
    }
    return conn;
  }

  @override
  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    super.listen((data) {
      if (link.method == 'CONNECT') {
        if (isBuildConnection) {
          onData!(data);
        }
      } else {
        onData!(data);
      }
    }, onError: onError, onDone: onDone);
  }
}
