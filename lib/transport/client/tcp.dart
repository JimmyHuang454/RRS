import 'package:proxy/transport/client/base.dart';

class TCPClient2 extends TransportClient {
  TCPClient2({required super.config}) : super(protocolName: 'tcp');
}
