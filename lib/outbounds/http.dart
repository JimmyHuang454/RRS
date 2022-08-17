import 'dart:io';
import 'package:proxy/utils/utils.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/outbounds/base.dart';

class HTTPOut extends OutboundStruct {
  String userAccount = '';
  String userPassword = '';

  HTTPOut({required super.tag, required super.clientTag, required super.config})
      : super(protocolName: 'http', protocolVersion: '1.1') {
    userAccount = getValue(config, 'setting.account', '');
    userPassword = getValue(config, 'setting.password', '');
  }

  @override
  Future<Socket> connect(Link link) {
    // TODO: implement newLink
    throw UnimplementedError();
  }
}
