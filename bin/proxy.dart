import 'dart:convert';
import 'dart:io';

import 'package:proxy/proxy.dart' as proxy;
import 'package:proxy/transport/client/base.dart';

var jsonString = '''{
  "protocol": "tcp",
  "protocolConfig": {},
  "mux": {"enabled": false, "concurrency": 10},
  "tls": {"enabled": true, "alpn": ["h2", "http/1.1"], "useSystemRoot": true, "certificate":"", "key": ""},
  "fakeRoute": {"enabled": false},
  "ip": {"strategy": "default"},
}''';

void buildStream() async{
  var securityContext = SecurityContext();
  securityContext.setTrustedCertificatesBytes

  Map<String, dynamic> user = jsonDecode(jsonString);
  if (!user.containsKey('protocol')) {
    return;
  }
}

void main(List<String> arguments) {
  print('Hello world: ${proxy.calculate()}!');
}
