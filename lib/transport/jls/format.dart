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
    clientHello = buildClientHello();
    serverHello = buildServerHello();
    changeSpec = ChangeSpec();
  }

  ClientHello buildClientHello() {
    var temp = (config['clientHello'] as String).codeUnits;
    return ClientHello.parse(rawData: List<int>.from(temp));
  }

  ServerHello buildServerHello() {
    var temp = (config['serverHello'] as String).codeUnits;
    return ServerHello.parse(rawData: List<int>.from(temp));
  }
}
