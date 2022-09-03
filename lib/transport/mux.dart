import 'dart:typed_data';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/server/base.dart';

class MuxInfo {
  //{{{
  int id = 0;
  int currentThreadID = 0;

  int currentLen = 0;
  int addedLen = 0;

  RRSSocket rrsSocket;
  void Function(RRSSocket rrsSocket)? newConnection;
  Map<int, RRSSocketMux> usingList = {};
  List<int> content = [];

  MuxInfo({required this.rrsSocket}) {
    rrsSocket.listen(
      (event) async {
        content += event;
        if (content.length < 9) {
          return;
        }

        RRSSocketMux dstSocket;
        if (currentThreadID == 0) {
          var inThreadID = content[0];
          currentThreadID = inThreadID;
          if (!usingList.containsKey(inThreadID)) {
            var temp = RRSSocketMux(threadID: inThreadID, muxInfo: this);
            usingList[inThreadID] = temp;
            newConnection!(temp);
          }
          dstSocket = usingList[inThreadID]!;

          Uint8List byteList = Uint8List.fromList(content.sublist(1, 9));
          ByteData byteData = ByteData.sublistView(byteList);
          currentLen = byteData.getUint64(0, Endian.big);
          addedLen = 0;

          content = content.sublist(9);
        } else {
          dstSocket = usingList[currentThreadID]!;
        }

        if (currentLen == 0) {
          close(currentThreadID);
        } else {
          dstSocket.onData2!(Uint8List.fromList(content));
        }

        addedLen += content.length;
        content = [];
        if (addedLen == currentLen) {
          currentThreadID = 0;
        }
      },
    );
  }

  void close(int inThreadID) {
    if (!usingList.containsKey(inThreadID)) {
      return;
    }
    RRSSocketMux dstSocket;
    dstSocket = usingList[inThreadID]!;
    dstSocket.onDone2!();

    usingList.remove(inThreadID);
  }
} //}}}

class RRSSocketMux extends RRSSocket {
  //{{{
  int threadID;
  MuxInfo muxInfo;

  void Function(Uint8List event)? onData2;
  Function? onError2;
  void Function()? onDone2;

  RRSSocketMux({required this.threadID, required this.muxInfo})
      : super(socket: muxInfo.rrsSocket.socket) ;

  @override
  void add(List<int> data) {
    var temp = [threadID];
    temp += Uint8List(8)
      ..buffer.asByteData().setUint64(0, data.length, Endian.big);
    temp += data;
    super.add(temp);
  }

  @override
  Future close() async {
    add([]);
    await super.close();
  }

  @override
  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    onData2 = onData;
    onDone2 = onDone;
    onError2 = onError2;
  }
} //}}}

class MuxClient {
  //{{{
  Map<String, List<MuxInfo>> mux = {};

  TransportClient1 transportClient1;

  MuxClient({required this.transportClient1});

  Future<RRSSocket> connect(host, int port) async {
    if (!transportClient1.isMux) {
      return await transportClient1.connect(host, port);
    }

    String dst = host + ":" + port.toString();
    late MuxInfo muxInfo;
    var isAssigned = false;

    if (!mux.containsKey(dst)) {
      mux[dst] = [];
    }

    for (var i = 0, len = mux[dst]!.length; i < len; ++i) {
      if (mux[dst]![i].usingList.length < transportClient1.maxThread) {
        muxInfo = mux[dst]![i];
        isAssigned = true;
        break;
      }
    }

    if (!isAssigned) {
      muxInfo = MuxInfo(rrsSocket: await transportClient1.connect(host, port));
      mux[dst]!.add(muxInfo);
    }

    muxInfo.id += 1;
    var temp = RRSSocketMux(threadID: muxInfo.id, muxInfo: muxInfo);
    muxInfo.usingList[muxInfo.id] = temp;
    return temp;
  }
} //}}}

class RRSServerSocketMux extends RRSServerSocket {
  //{{{
  RRSServerSocketMux({required super.serverSocket});
  // List<MuxInfo> mux = [];

  @override
  void listen(void Function(RRSSocket rrsSocket)? onData,
      {Function? onError, void Function()? onDone}) {
    super.listen((rrsSocket) {
      var muxInfo = MuxInfo(rrsSocket: rrsSocket);
      muxInfo.newConnection = onData;
      // mux.add(muxInfo);
    }, onError: onError, onDone: onDone);
  }
} //}}}

class MuxServer {
  //{{{
  TransportServer1 transportServer1;

  MuxServer({
    required this.transportServer1,
  });

  Future<RRSServerSocket> bind(address, int port) async {
    var res = await transportServer1.bind(address, port);
    if (!transportServer1.isMux) {
      return res;
    }
    return RRSServerSocketMux(serverSocket: res.serverSocket);
  }
} //}}}
