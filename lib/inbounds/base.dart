import 'dart:io';
import 'package:proxy/outbounds/base.dart';

class Link {
  Socket client; // in
  late Socket server; // out

  late Uri targetUri; // if it's a HTTP request.
  String method = 'GET';

  String typeOfAddress = 'domain'; // domain | ipv4 | ipv6
  String targetAddress = '';
  String streamType = 'TCP'; // TCP | UDP

  String userID = 'none';
  bool isTLS = false;
  bool isHTTPRequest = false;
  bool isBitcont = false;
  int timeout = 100;
  bool isValidRequest = false;

  InboundStruct inboundStruct;
  late OutboundStruct outboundStruct; // assign after routing.

  Link(this.client, this.inboundStruct);
}

class InboundStruct {
  String protocolName;
  String protocolVersion;
  String tag;

  ServerSocket server;
  Map<String, dynamic> config;

  String address;
  int port;

  int totalClient = 0;

  InboundStruct(
      {required this.tag,
      required this.protocolName,
      required this.protocolVersion,
      required this.server,
      this.config = const {},
      this.address = '',
      this.port = 80});
}
