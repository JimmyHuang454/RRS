import 'package:proxy/transport/jls/tls/base.dart';

class FingerPrint {
  String tag = '';

  late List<int> rawClientHello;
  late List<int> rawServerHello;

  ClientHello? clientHello;
  ServerHello? serverHello;
  ChangeSpec? changeSpec;

  Map<String, dynamic> config;

  FingerPrint({required this.config}) {
    clientHello = ClientHello.parse(
        rawData: List<int>.from((config['clientHello'] as String).codeUnits));
    serverHello = ServerHello.parse(
        rawData: List<int>.from((config['serverHello'] as String).codeUnits));
    changeSpec = ChangeSpec();
  }
}
