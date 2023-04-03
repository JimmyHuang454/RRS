import 'package:proxy/inbounds/base.dart';
import 'package:proxy/outbounds/base.dart';
import 'package:proxy/route/mmdb.dart';
import 'package:proxy/route/route.dart';
import 'package:proxy/user.dart';

import 'transport/mux.dart';

Map<String, MuxClient> outStreamList = {};
Map<String, MuxServer> inStreamList = {};

Map<String, OutboundStruct> outboundsList = {};
Map<String, InboundStruct> inboundsList = {};

Map<String, Route> routeList = {};

Map<String, MMDB> ipdbList = {};
Map<List<int>, User> userList = {};
