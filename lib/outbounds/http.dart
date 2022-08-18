import 'dart:io';
import 'package:proxy/utils/utils.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/outbounds/base.dart';

class HTTPOut extends OutboundStruct {
  String userAccount = '';
  String userPassword = '';
  String httpAddress = '';
  int httpPort = 80;

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

  @override
  Future<Socket> connect2(Link link) {
    var server = getClient()();
    return server.connect(httpAddress, httpPort).then(
      (value) {
        link.server = value;
        return value;
      },
    );
  }
}
