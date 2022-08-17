import 'dart:io';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/outbounds/base.dart';
import 'package:proxy/utils/utils.dart';

class FreedomOut extends OutboundStruct {
  String outStrategy = 'default'; // OS default.

  FreedomOut({required super.tag, required super.client, required super.config})
      : super(protocolName: 'freedom', protocolVersion: '1') {
    outStrategy = getValue(config, 'setting.strategy', 'default');
    if (!['default', 'ipv4', 'ipv6'].contains(outStrategy)) {
      throw "wrong strategy.";
    }
  }

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
