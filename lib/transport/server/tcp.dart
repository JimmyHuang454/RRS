import 'package:proxy/transport/server/base.dart';
import 'package:proxy/utils/utils.dart';

class TCPServer extends TransportServer {
  TCPServer({required super.tag, required super.config})
      : super(protocolName: 'tcp') {
    super.useTLS = getValue(config, 'tls.enabled', false);
    super.requestClientCertificate = getValue(config, 'tls.requireClientCertificate', true);
    super.supportedProtocols = getValue(config, 'tls.supportedProtocols', []);
  }
}
