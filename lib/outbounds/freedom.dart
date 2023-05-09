import 'package:proxy/outbounds/base.dart';

class FreedomOut extends OutboundStruct {
  FreedomOut({required super.config})
      : super(protocolName: 'freedom', protocolVersion: '1');
}
