import 'dart:typed_data';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/server/base.dart';

class MuxInfo {
  int id = 0;
  int currentThreadID = 0;
  int currentLen = 0;
  int addedLen = 0;
  bool isListened = false;
  RRSSocket rrsSocket;
  Map<int, RRSSocketMux> usingList = {};

  MuxInfo({required this.rrsSocket});

  List<int> content = [];
}

class ServerMuxInfo {
  bool isListened = false;
  RRSServerSocket rrsServerSocket;
  Map<int, RRSServerSocketMux> usingList = {};

  ServerMuxInfo({required this.rrsServerSocket});

  List<int> content = [];
}

class RRSSocketMux extends RRSSocket {
  //{{{
  int threadID;
  MuxInfo muxInfo;

  void Function(Uint8List event)? onData2;
  Function? onError2;
  void Function()? onDone2;

  RRSSocketMux(
      {required super.socket, required this.threadID, required this.muxInfo});

  RRSSocketMux getByThreadID(int threadID) {
    return muxInfo.usingList[threadID]!;
  }

  @override
  void add(List<int> data) {
    var temp = [threadID];
    temp += Uint8List(8)
      ..buffer.asByteData().setUint64(0, data.length, Endian.big);
    temp += data;
    socket.add(temp);
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
    if (muxInfo.isListened) {
      return;
    }
    muxInfo.isListened = true;

    muxInfo.rrsSocket.listen(
      (event) async {
        muxInfo.content += event;
        if (muxInfo.content.length < 9) {
          return;
        }

        RRSSocketMux dstSocket;
        if (muxInfo.currentThreadID == 0) {
          var inThreadID = muxInfo.content[0];
          muxInfo.currentThreadID = inThreadID;
          dstSocket = muxInfo.usingList[inThreadID]!;

          Uint8List byteList =
              Uint8List.fromList(muxInfo.content.sublist(1, 9));
          ByteData byteData = ByteData.sublistView(byteList);
          muxInfo.currentLen = byteData.getUint64(0, Endian.big);
          muxInfo.addedLen = 0;

          muxInfo.content = muxInfo.content.sublist(9);
        } else {
          dstSocket = muxInfo.usingList[muxInfo.currentThreadID]!;
        }

        if (muxInfo.currentLen == 0) {
          dstSocket.onDone2!();
        } else {
          dstSocket.onData2!(Uint8List.fromList(muxInfo.content));
        }

        muxInfo.addedLen += muxInfo.content.length;
        muxInfo.content = [];
        if (muxInfo.addedLen == muxInfo.currentLen) {
          muxInfo.currentThreadID = 0;
        }
      },
    );
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
    var temp = RRSSocketMux(
        socket: muxInfo.rrsSocket, threadID: muxInfo.id, muxInfo: muxInfo);
    muxInfo.usingList[muxInfo.id] = temp;
    return temp;
  }
} //}}}

class RRSServerSocketMux extends RRSServerSocket {
  //{{{
  RRSServerSocketMux({required super.serverSocket});

  @override
  void listen(void Function(RRSSocket event)? onData,
      {Function? onError, void Function()? onDone}) {
    super.listen((event) {
      onData!(event);
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
    return RRSServerSocket(serverSocket: res);
  }
} //}}}
