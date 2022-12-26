import 'package:proxy/transport/client/base.dart';

class TCPClient extends TransportClient {
  TCPClient({required super.config}) : super(protocolName: 'tcp');
}
