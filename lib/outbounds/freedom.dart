import 'dart:io';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/outbounds/base.dart';

class FreedomOut extends OutboundStruct {
  FreedomOut({required super.tag, required super.client})
      : super(protocolName: 'freedom', protocolVersion: '1');

  @override
  Future<Socket> connect(Link link) async {
    return Socket.connect(link.targetUri.host, link.targetUri.port).then(
      (value) {
        link.server = value;
        return value;
      },
    );
  }
}
