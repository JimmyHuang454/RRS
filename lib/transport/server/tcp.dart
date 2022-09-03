import 'package:proxy/transport/server/base.dart';

class TCPServer extends TransportServer {
  TCPServer({required super.config}) : super(protocolName: 'tcp');
}

class TCPServer2 extends TransportServer1 {
  TCPServer2({required super.config}) : super(protocolName: 'tcp');
}
