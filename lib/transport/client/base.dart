import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:proxy/outbounds/base.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:proxy/utils/utils.dart';

Map<String, List<MuxInfo>> mux = {};

class MuxInfo {
  int linkID = 0;
  int currentThreadID = 0;
  int currentLen = 0;
  int addedLen = 0;
  TransportClient transportClient;
  bool isListened = false;
  Map<int, RawtransportClientMux> transportClientMuxList = {};

  List<int> content = [];

  MuxInfo({required this.transportClient});
}

class TransportClient {
  //{{{
  String status = 'init';
  String tag = '';
  String protocolName;
  Map<String, dynamic> config;

  late Socket socket;
  List<dynamic> streamSubscription = [];

  // TLS
  late bool useTLS;
  late bool allowInsecure;
  late bool useSystemRoot;
  late List<String> supportedProtocols;

  late int connectionTimeout;
  late Duration timeout;
  late SecurityContext securityContext;

  TransportClient({required this.protocolName, required this.config}) {
    tag = getValue(config, 'tag', '');
    useTLS = getValue(config, 'tls.enabled', false);
    allowInsecure = getValue(config, 'tls.allowInsecure', false);
    useSystemRoot = getValue(config, 'tls.useSystemRoot', true);
    supportedProtocols =
        getValue(config, 'tls.supportedProtocols', ['http/1.1']);
    connectionTimeout = getValue(config, 'connectionTimeout', 100);
    timeout = Duration(seconds: connectionTimeout);
  }

  void load(s) {
    socket = s;
  }

  Future<void> connect(host, int port) async {
    if (useTLS) {
      socket = await SecureSocket.connect(host, port,
          context: securityContext,
          supportedProtocols: supportedProtocols,
          onBadCertificate: onBadCertificate,
          timeout: timeout);
    } else {
      socket = await Socket.connect(host, port, timeout: timeout);
    }
    status = 'created';
  }

  bool onBadCertificate(X509Certificate certificate) {
    return allowInsecure;
  }

  Future<void> clearListen() async {
    for (var i = 0, len = streamSubscription.length; i < len; ++i) {
      await streamSubscription[i].cancel();
    }
    streamSubscription = [];
  }

  void add(List<int> data) {
    socket.add(data);
  }

  Future close() async {
    status = 'closed';
    await socket.close();
    await clearListen();
  }

  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    var temp = socket.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: true);

    socket.done.then((value) {
      if (onDone != null) {
        onDone();
      }
    }, onError: (e) {
      if (onError != null) {
        onError(e);
      }
    });

    streamSubscription.add(temp);
  }
} //}}}

class RawtransportClientMux extends TransportClient {
  //{{{
  late MuxInfo muxInfo;
  TransportClient Function() newTransportClient;
  bool isListened = false;

  late void Function(Uint8List event) onData;
  late Function onError;
  late void Function() onDone;

  late int threadID;
  int maxThread = 8;

  RawtransportClientMux(
      {required super.config,
      required super.protocolName,
      required this.newTransportClient});

  @override
  Future<void> connect(host, int port) async {
    String dst = host + port;
    if (!mux.containsKey(dst)) {
      var temp = newTransportClient();
      var temp2 = MuxInfo(transportClient: temp);
      mux[dst] = [temp2];
      muxInfo = temp2;
      await temp.connect(host, port);
    } else {
      var isAssigned = false;
      for (var i = 0, len = mux[dst]!.length; i < len; ++i) {
        if (mux[dst]![i].transportClientMuxList.length < maxThread) {
          muxInfo = mux[dst]![i];
          isAssigned = true;
          break;
        }
      }
      if (!isAssigned) {
        var temp = newTransportClient();
        var temp2 = MuxInfo(transportClient: temp);
        mux[dst]!.add(temp2);
        muxInfo = temp2;
        await temp.connect(host, port);
      }
    }

    muxInfo.linkID += 1;
    threadID = muxInfo.linkID;
    muxInfo.transportClientMuxList[muxInfo.linkID] = this;
  }

  @override
  void add(List<int> data) {
    if (data.isEmpty) {
      return;
    }
    var temp = [muxInfo.linkID];
    temp += Uint8List(8)
      ..buffer.asByteData().setUint64(0, data.length, Endian.big);
    muxInfo.transportClient.add(temp + data);
  }

  @override
  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    onData = onData;
    onError = onError;
    onDone = onDone;
    isListened = true;
    if (!muxInfo.isListened) {
      muxInfo.isListened = true;
      muxInfo.transportClient.listen(
        (event) {
          muxInfo.content += event;
          if (muxInfo.content.length < 9) {
            return;
          }
          if (muxInfo.currentThreadID == 0) {
            muxInfo.currentThreadID = muxInfo.content[0];
            Uint8List byteList =
                Uint8List.fromList(muxInfo.content.sublist(1, 9));
            ByteData byteData = ByteData.sublistView(byteList);
            muxInfo.currentLen = byteData.getUint64(0, Endian.big);
            muxInfo.addedLen = 0;

            muxInfo.content = muxInfo.content.sublist(9);
            if (muxInfo.content.isEmpty) {
              muxInfo.currentThreadID = 0;
              onDone!();
              return;
            }
          }

          muxInfo.addedLen += muxInfo.content.length;
          if (muxInfo.transportClientMuxList
              .containsKey(muxInfo.currentThreadID)) {
            var temp = muxInfo.transportClientMuxList[muxInfo.currentThreadID];
            temp!.add(muxInfo.content);
          }
          muxInfo.content = [];

          if (muxInfo.addedLen == muxInfo.currentLen) {
            muxInfo.currentThreadID = 0;
          }
        },
      );
    }
  }
} //}}}

class Connect extends TransportClient {
  //{{{
  TransportClient transportClient;
  OutboundStruct outboundStruct;
  Link link;
  late RawDatagramSocket udpClient;

  Connect(
      {required this.transportClient,
      required this.link,
      required this.outboundStruct})
      : super(protocolName: 'connecting', config: {});

  @override
  Future<void> connect(host, int port) async {
    if (link.streamType == 'TCP') {
      await transportClient.connect(host, port);
    } else {
      udpClient = await RawDatagramSocket.bind(host, port);
    }
  }

  @override
  void add(List<int> data) {
    if (link.streamType == 'TCP') {
      transportClient.add(data);
    } else {
      udpClient.send(
          data, InternetAddress(link.targetAddress.address), link.targetport);
    }
    outboundStruct.traffic.uplink += data.length;
    link.traffic.uplink += data.length;
  }

  @override
  Future close() async {
    if (link.streamType == 'TCP') {
      await transportClient.close();
    } else {
      udpClient.close();
    }
  }

  @override
  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    if (link.streamType == 'TCP') {
      transportClient.listen((data) {
        link.traffic.downlink += data.length;
        outboundStruct.traffic.downlink += data.length;
        onData!(data);
      }, onDone: onDone, onError: onError);
    } else {
      var temp = udpClient.listen((event) {
        Datagram? d = udpClient.receive();
        if (d == null) {
          return;
        }
        var data = d.data;
        link.traffic.downlink += data.length;
        outboundStruct.traffic.downlink += data.length;
        onData!(data);
      }, onError: onError, onDone: onDone, cancelOnError: true);
      streamSubscription.add(temp);
    }
  }
} //}}}
