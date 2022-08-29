import 'package:proxy/outbounds/base.dart';
import 'package:proxy/transport/server/base.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/obj_list.dart';
import 'package:proxy/user.dart';
import 'package:proxy/utils/utils.dart';

class Link {
  TransportClient client; // in
  late TransportClient server; // out

  late Uri targetUri; // if it's a HTTP request.
  String method = 'GET';
  int cmd = 0;

  late Address targetAddress;
  int targetport = 0;
  String streamType = 'TCP'; // TCP | UDP

  String protocolVersion = '';
  List<int> userID = [];
  bool isTLS = false;
  bool isHTTPRequest = false;
  bool isBitcont = false;
  int timeout = 100;
  bool isValidRequest = false;
  bool isClosedAll = false;

  InboundStruct inboundStruct;
  late OutboundStruct outboundStruct; // assign after routing.

  Stopwatch createdTime = Stopwatch()..start();
  Traffic traffic = Traffic();
  String linkInfo = '';

  Link({required this.client, required this.inboundStruct});

  Future<void> closeAll() async {
    try {
      await server.clearListen();
    } catch (_) {}

    try {
      await client.clearListen();
    } catch (_) {}

    try {
      await server.close();
    } catch (e) {
      // devPrint(e);
    }

    try {
      await client.close();
    } catch (e) {
      // devPrint(e);
    }
    try {
      if (!isClosedAll) {
        devPrint(
            'Closed: ${buildLinkInfo()} [${toMetric(traffic.uplink, 2)}B/${toMetric(traffic.downlink, 2)}B]');
      }
      isClosedAll = true;
    } catch (e) {
      devPrint(e);
    }
  }

  void clientAdd(List<int> data) {
    try {
      client.add(data);
    } catch (e) {
      // devPrint(e);
    }
  }

  void serverAdd(List<int> data) {
    try {
      server.add(data);
    } catch (e) {
      devPrint(e);
    }
  }

  Future<bool> bindServer() async {
    outboundStruct = await inboundStruct.doRoute(this);
    try {
      server = await outboundStruct.newConnect(this);
    } catch (e) {
      devPrint(e);
      await closeAll();
      return false;
    }

    try {
      devPrint('Created: ${buildLinkInfo()}');
    } catch (e) {
      devPrint(e);
    }

    server.listen((event) {
      clientAdd(event);
    }, onDone: () async {
      await closeAll();
    }, onError: (e) async {
      await closeAll();
    });

    server.done.then((value) async {
      await closeAll();
    }, onError: (e) async {
      await closeAll();
    });
    return true;
  }

  String buildLinkInfo() {
    if (linkInfo == '') {
      linkInfo =
          "{${client.remoteAddress.address}:${client.remotePort}} [${inboundStruct.tag}:${inboundStruct.protocolName}] (${targetAddress.address}:$targetport) --> {${outboundStruct.realOutAddress}:${outboundStruct.realOutPort}} [${outboundStruct.tag}:${outboundStruct.protocolName}] (${createdTime.elapsed})";
    }
    return linkInfo;
  }
}

abstract class InboundStruct {
  String protocolName;
  String protocolVersion;

  int upLinkByte = 0;
  int downLinkByte = 0;

  late String inAddress;
  late int inPort;
  late String tag;
  late String inStream;
  late String route;

  Map<String, dynamic> config;

  int totalClient = 0;

  InboundStruct(
      {required this.protocolName,
      required this.protocolVersion,
      required this.config}) {
    tag = config['tag'];
    inStream = getValue(config, 'inStream', '');
    route = getValue(config, 'route', '');
    inAddress = getValue(config, 'setting.address', '');
    inPort = getValue(config, 'setting.port', 0);

    if (inStream == '' || route == '') {
      throw 'inStream and route can NOT be null.';
    }
  }

  Future<void> bind();

  TransportServer getServer() {
    if (!inStreamList.containsKey(inStream)) {
      throw "wrong inStream tag.";
    }
    return inStreamList[inStream]!();
  }

  Future<OutboundStruct> doRoute(Link link) async {
    if (!routeList.containsKey(route)) {
      throw 'There are no route named "$route"';
    }
    var outbound = await routeList[route]!.match(link);
    link.outboundStruct = outboundsList[outbound]!;
    return link.outboundStruct;
  }
}
