import 'package:proxy/outbounds/base.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/utils/utils.dart';

class FreedomConnect extends Connect2 {
  FreedomConnect(
      {required super.rrsSocket,
      required super.link,
      required super.outboundStruct});
}

class FreedomOut extends OutboundStruct {
  String outStrategy = 'default'; // OS default.

  FreedomOut({required super.config})
      : super(protocolName: 'freedom', protocolVersion: '1') {
    outStrategy = getValue(config, 'setting.strategy', 'default');
    if (!['default', 'ipv4', 'ipv6'].contains(outStrategy)) {
      throw "wrong strategy.";
    }

    var temp = getClient();
    if (temp.transportClient1.isMux) {
      throw "Freedom outbound should NOT enable mux.";
    }
  }
}
