import 'package:proxy/transport/client/base.dart';

class TCPClient extends TransportClient {
  TCPClient(
      {super.allowInsecure = false,
      super.securityContext,
      super.keyLog,
      super.supportedProtocols})
      : super(protocolName: 'tcp');
}
