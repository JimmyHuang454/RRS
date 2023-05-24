import 'package:proxy/transport/jls/jls.dart';

class JLSHandShakeClientSide extends JLSHandShakeSide {
  JLSHandShakeClientSide(
      {required super.psk, required super.nonceStr, required super.otherMac});
}
