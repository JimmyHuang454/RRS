import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:proxy/utils/utils.dart';

Map<String, MuxInfo> mux = {};

class MuxInfo {
  int linkID = 0;
  int currentLinkID = 0;
  int currentLen = 0;
  int addedLen = 0;
  TransportClient transportClient;
  bool isListened = false;
  Map<int, TransportClientMux> transportClientMuxList = {};

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
    // securityContext = SecurityContext(withTrustedRoots: useSystemRoot);
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

    streamSubscription.add(temp);
  }

  Future get done => socket.done;
  InternetAddress get remoteAddress => socket.remoteAddress;
  int get remotePort => socket.remotePort;
} //}}}

class TransportClientMux extends TransportClient {
  late MuxInfo muxInfo;
  TransportClient Function() newTransportClient;
  bool isListened = false;

  late void Function(Uint8List event) onData;
  late Function onError;
  late void Function() onDone;

  TransportClientMux(
      {required super.config,
      required super.protocolName,
      required this.newTransportClient});

  @override
  Future<void> connect(host, int port) async {
    String dst = host + port;
    if (!mux.containsKey(dst)) {
      var temp = newTransportClient();
      mux[dst] = MuxInfo(transportClient: temp);
      await temp.connect(host, port);
    }
    muxInfo = mux[dst]!;
    muxInfo.linkID += 1;
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
      muxInfo.transportClient.listen(
        (event) {
          muxInfo.content += event;
          if (muxInfo.content.length < 9) {
            return;
          }
          if (muxInfo.currentLinkID == 0) {
            muxInfo.currentLinkID = muxInfo.content[0];
          }

          Uint8List byteList =
              Uint8List.fromList(muxInfo.content.sublist(1, 9));
          ByteData byteData = ByteData.sublistView(byteList);
          muxInfo.currentLen = byteData.getUint64(0, Endian.big);
        },
      );
    }
  }
}
