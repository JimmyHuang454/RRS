import 'package:proxy/outbounds/base.dart';
import 'package:proxy/transport/mux.dart';
import 'package:proxy/transport/client/base.dart';
import 'package:proxy/obj_list.dart';
import 'package:proxy/utils/utils.dart';

class Link {
  RRSSocket client; // in
  RRSSocket? server; // out

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
  String linkInfo = '';

  Link({required this.client, required this.inboundStruct});

  Future<void> closeClient() async {
    await client.close();
  }

  Future<void> closeServer() async {
    if (server != null) {
      await server!.close();
    }
  }

  Future<void> closeAll() async {
    // await client.clearListen();
    // if (server != null) {
    //   await server!.clearListen();
    // }
    await closeServer();
    await closeClient();
  }

  Future<void> clientAdd(List<int> data) async {
    try {
      client.add(data);
    } catch (e) {
      devPrint(e);
    }
  }

  void serverAdd(List<int> data) {
    if (server != null) {
      try {
        server!.add(data);
      } catch (e) {
        devPrint(e);
      }
    }
  }

  Future<bool> bindServer() async {
    client.done.then((e) async {
      await closeAll();
    }, onError: (e) async {
      await closeAll();
    });

    outboundStruct = await inboundStruct.doRoute(this);
    try {
      server = await outboundStruct.newConnect(this);
    } catch (e) {
      await closeAll();
      return false;
    }

    outboundStruct.linkNr += 1;
    devPrint('Created: ${buildLinkInfo()}');

    server!.listen((event) async {
      await clientAdd(event);
    }, onDone: () async {
      await closeClient();
      devPrint('server closed');
    }, onError: (e) async {
      await closeClient();
    });

    server!.done.then((e) {
      serverDone();
    }, onError: (e) {
      serverDone();
    });

    return true;
  }

  void serverDone() {
    closeAll();
    outboundStruct.linkNr -= 1;
    devPrint(
        'Closed: ${buildLinkInfo()} [${toMetric(server!.traffic.uplink, 2)}B/${toMetric(server!.traffic.downlink, 2)}B]');
    devPrint(
        '${outboundStruct.tag}:${outboundStruct.protocolName} [${toMetric(outboundStruct.traffic.uplink, 2)}B/${toMetric(outboundStruct.traffic.downlink, 2)}B] ${outboundStruct.linkNr}');
  }

  String buildLinkInfo() {
    if (linkInfo == '') {
      linkInfo =
          " [${inboundStruct.tag}:${inboundStruct.protocolName}] (${targetAddress.address}:$targetport) -<${outboundStruct.getClient().transportClient1.protocolName}>-> {${outboundStruct.realOutAddress}:${outboundStruct.realOutPort}} [${outboundStruct.tag}:${outboundStruct.protocolName}]";
    }
    return '$linkInfo (${createdTime.elapsed})';
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

  MuxServer getServer() {
    if (!inStreamList.containsKey(inStream)) {
      throw "wrong inStream tag.";
    }
    return inStreamList[inStream]!;
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
