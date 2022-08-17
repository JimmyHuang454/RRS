import 'dart:io';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/inbounds/base.dart';

abstract class OutboundStruct {
  String protocolName;
  String protocolVersion;
  String tag;

  TransportClient Function() client;
  Map<String, dynamic> config;

  bool useFakeDNS;
  String host;
  int port;

  OutboundStruct(
      {required this.tag,
      required this.protocolName,
      required this.protocolVersion,
      required this.client,
      this.useFakeDNS = false,
      this.config = const {},
      this.host = '',
      this.port = 80});

  Future<Socket> connect(Link link);
}
