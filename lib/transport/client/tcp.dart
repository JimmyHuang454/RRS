import 'package:proxy/transport/client/base.dart';

class TCPClient extends TransportClient {
  TCPClient({required super.config}) : super(protocolName: 'tcp');
}

class TCPClient2 extends TransportClient1 {
  TCPClient2({required super.config}) : super(protocolName: 'tcp');
}
