import 'dart:io';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/outbounds/base.dart';

class HTTPOut extends OutboundStruct {

  HTTPOut(
      {required super.tag,
      required super.client,
      required super.host,
      required super.port})
      : super(protocolName: 'http', protocolVersion: '1.1');

  @override
  Future<Socket> connect(Link link) {
    // TODO: implement newLink
    throw UnimplementedError();
  }
}
