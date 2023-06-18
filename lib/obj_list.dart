import 'package:proxy/balance/balancer.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/outbounds/base.dart';
import 'package:proxy/route/mmdb.dart';
import 'package:proxy/route/route.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/jls/format.dart';
import 'package:proxy/transport/server/base.dart';
import 'package:proxy/user.dart';

import 'dns/dns.dart';

Map<String, TransportClient> outStreamList = {};
Map<String, TransportServer> inStreamList = {};

Map<String, OutboundStruct> outboundsList = {};
Map<String, InboundStruct> inboundsList = {};

Map<String, Route> routeList = {};

Map<String, MMDB> ipdbList = {};
Map<String, DNS> dnsList = {};
Map<String, User> userList = {};
Map<String, Balancer> balancerList = {};
Map<String, FingerPrint> jlsFringerPrintList = {};
