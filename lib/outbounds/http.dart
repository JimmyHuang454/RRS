import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:proxy/utils/utils.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/outbounds/base.dart';

class HTTPOut extends OutboundStruct {
  String userAccount = '';
  String userPassword = '';
  String httpAddress = '';
  int httpPort = 80;
  bool isBuildConnection = false;
  late Link link;

  HTTPOut({required super.config})
      : super(protocolName: 'http', protocolVersion: '1.1') {
    userAccount = getValue(config, 'setting.account', '');
    userPassword = getValue(config, 'setting.password', '');
    httpAddress = getValue(config, 'setting.address', '');
    httpPort = getValue(config, 'setting.port', 0);

    if (httpAddress == '' || httpPort == 0) {
      throw '"address" and "port" can not be empty in http setting.';
    }
  }

  List<int> _buildConnectionRequest() {
    return '${link.method} ${link.targetUri.toString()} ${link.protocolVersion}\r\n\r\n'
        .codeUnits;
  }

  @override
  Future<Socket> connect2(Link link) {
    link = link;
    return socket.connect(httpAddress, httpPort).then(
      (value) async {
        link.server = value;
        if (link.method == 'CONNECT') {
          add(_buildConnectionRequest());
        }
        return value;
      },
    );
  }

  @override
  void add(List<int> data) {
    socket.add(data);
  }

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return socket.listen((data) {
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
