import 'package:proxy/transport/server/base.dart';

class TCPServer extends TransportServer {
  TCPServer() : super(protocolName: 'tcp');
}
