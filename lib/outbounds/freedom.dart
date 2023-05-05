import 'package:proxy/outbounds/base.dart';
import 'package:proxy/transport/client/base.dart';

class FreedomConnect extends Connect {
  FreedomConnect(
      {required super.rrsSocket,
      required super.link,
      required super.outboundStruct});
}

class FreedomOut extends OutboundStruct {
  FreedomOut({required super.config})
      : super(protocolName: 'freedom', protocolVersion: '1');
}
