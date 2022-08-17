import 'package:proxy/transport/server/base.dart';
import 'package:proxy/transport/client/base.dart';

Map<String, TransportClient Function()> outStreamList = {};
Map<String, TransportServer Function()> inStreamList = {};
