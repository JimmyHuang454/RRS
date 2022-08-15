import 'package:proxy/transport/client/base.dart';

class TCPClient extends TransportClient {
  TCPClient(
      {super.allowInsecure = false,
      super.keyLog,
      super.useTLS,
      super.useSystemRoot,
      super.supportedProtocols})
      : super(protocolName: 'tcp');
}
