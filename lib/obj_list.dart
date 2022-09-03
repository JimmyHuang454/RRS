import 'package:proxy/transport/server/base.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/outbounds/base.dart';
import 'package:proxy/route/route.dart';

import 'transport/mux.dart';

Map<String, MuxClient> outStreamList = {};
Map<String, TransportServer Function()> inStreamList = {};

Map<String, OutboundStruct> outboundsList = {};
Map<String, InboundStruct> inboundsList = {};

Map<String, Route> routeList = {};
