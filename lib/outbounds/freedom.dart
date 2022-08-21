import 'dart:io';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/outbounds/base.dart';
import 'package:proxy/utils/utils.dart';

class FreedomOut extends OutboundStruct {
  String outStrategy = 'default'; // OS default.

  FreedomOut({required super.config})
      : super(protocolName: 'freedom', protocolVersion: '1') {
    outStrategy = getValue(config, 'setting.strategy', 'default');
    if (!['default', 'ipv4', 'ipv6'].contains(outStrategy)) {
      throw "wrong strategy.";
    }
  }

  @override
  Future<Socket> connect2(Link link) async {
    return socket.connect(link.targetAddress, link.targetport).then(
      (value) {
        link.server = value;
        return value;
      },
    );
  }
}
