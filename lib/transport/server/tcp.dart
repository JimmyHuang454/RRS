import 'package:proxy/transport/server/base.dart';

class TCPServer extends TransportServer {
  TCPServer(
      {super.useTLS,
      super.backlog,
      super.v6Only,
      super.requestClientCertificate,
      super.requireClientCertificate,
      super.supportedProtocols,
      super.shared})
      : super(protocolName: 'tcp');
}
