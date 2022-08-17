import 'package:proxy/transport/server/base.dart';

class TCPServer extends TransportServer {
  TCPServer({required super.tag, required super.config})
      : super(protocolName: 'tcp');
}
