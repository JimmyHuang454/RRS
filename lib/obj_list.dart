import 'package:proxy/transport/server/base.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/outbounds/base.dart';
import 'package:proxy/route/route.dart';

Map<String, TransportClient Function()> outStreamList = {};
Map<String, TransportServer Function()> inStreamList = {};

Map<String, OutboundStruct Function()> outboundsList = {};
Map<String, InboundStruct> inboundsList = {};

Map<String, Route> routeList = {};
