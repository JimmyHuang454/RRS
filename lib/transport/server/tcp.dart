import 'package:proxy/transport/server/base.dart';

class TCPServer extends TransportServer {
  TCPServer({required super.config}) : super(protocolName: 'tcp');
}
