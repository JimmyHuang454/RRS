import 'dart:typed_data';

import 'package:proxy/transport/client/base.dart';
import 'package:crypto/crypto.dart';
import 'package:proxy/transport/server/base.dart';
import 'package:proxy/user.dart';
import 'package:quiver/collection.dart';

class MuxInfo {
  //{{{
  int muxInfoID;

  int id = 0;
  int currentThreadID = 0;

  int currentLen = 0;
  int addedLen = 0;

  RRSSocket rrsSocket;
  void Function(RRSSocket rrsSocket)? newConnection;
  Map<int, RRSSocketMux> usingList = {};
  List<int> content = [];
  List<int> muxPasswordSha224;
  bool isAuth = false;
  bool isFake = false;

  MuxInfo(
      {required this.rrsSocket,
      required this.muxInfoID,
      required this.muxPasswordSha224}) {
    rrsSocket.listen((event) async {
      content += event;
      if (!isAuth) {
        if (content.length < 56) {
          return;
        }
        var pwd = content.sublist(0, 56);
        if (!listsEqual(pwd, muxPasswordSha224)) {
          isFake = true;
        } else {
          content = content.sublist(56);
        }
        isAuth = true;
      }

      if (isFake && isAuth) {
        // TODO: pass to fake tunnel.
        return;
      }

      if (content.length < 9) {
        return;
      }

      RRSSocketMux dstSocket;
      if (currentThreadID == 0) {
        var inThreadID = content[0];
        currentThreadID = inThreadID;
        if (!usingList.containsKey(inThreadID)) {
          var temp = RRSSocketMux(
              threadID: inThreadID,
              muxInfo: this,
              muxPasswordSha224: muxPasswordSha224);
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
        await close(currentThreadID);
      } else {
        dstSocket.onData2!(Uint8List.fromList(content));
      }

      addedLen += content.length;
      content = [];
      if (addedLen == currentLen) {
        currentThreadID = 0;
      }
    }, onDone: () async {
      await closeAll();
    }, onError: (e) async {
      await closeAll();
    });
  }

  Future<void> closeAll() async {
    usingList.forEach(
      (key, value) async {
        await close(key);
      },
    );
  }

  Future<void> close(int inThreadID) async {
    if (!usingList.containsKey(inThreadID)) {
      return;
    }
    RRSSocketMux dstSocket;
    dstSocket = usingList[inThreadID]!;

    if (dstSocket.onDone2 != null) {
      dstSocket.onDone2!();
    }

    usingList.remove(inThreadID);

    if (usingList.isEmpty) {
      try {
        await rrsSocket.close();
      } catch (e) {
        print(e);
      }
    }
  }
} //}}}

class RRSSocketMux extends RRSSocket {
  //{{{
  int threadID;
  MuxInfo muxInfo;
  List<int> muxPasswordSha224;

  late RRSSocket rrsSocket;

  void Function(Uint8List event)? onData2;
  Function? onError2;
  void Function()? onDone2;

  RRSSocketMux(
      {required this.threadID,
      required this.muxInfo,
      required this.muxPasswordSha224})
      : super(socket: muxInfo.rrsSocket.socket) {
    rrsSocket = muxInfo.rrsSocket;
  }

  @override
  void add(List<int> data) {
    var temp = [threadID];
    temp += Uint8List(8)
      ..buffer.asByteData().setUint64(0, data.length, Endian.big);
    temp += data;
    rrsSocket.add(temp);
  }

  @override
  Future close() async {
    add([]); // send a empty datagram.
    muxInfo.close(threadID);
  }

  @override
  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    onData2 = onData;
    onError2 = onError2;
    onDone2 = onDone;
  }

  @override
  bool get isClosed => rrsSocket.isClosed;

  @override
  dynamic get socket => rrsSocket.socket;

  @override
  List get streamSubscription => rrsSocket.streamSubscription;

  @override
  Traffic get traffic => rrsSocket.traffic;

  @override
  Future<void> clearListen() async {
    await rrsSocket.clearListen();
  }

  @override
  Future<dynamic> get done => rrsSocket.done;
} //}}}

class MuxClient {
  //{{{
  Map<String, Map<int, MuxInfo>> mux = {};

  int muxInfoID = 0;

  TransportClient1 transportClient1;
  List<int> muxPasswordSha224 = [];

  MuxClient({required this.transportClient1}) {
    if (transportClient1.isMux) {
      if (transportClient1.muxPassword == '') {
        throw "muxPassword can not be null.";
      }
      muxPasswordSha224 = sha224
          .convert(transportClient1.muxPassword.codeUnits)
          .toString()
          .codeUnits;
    }
  }

  void clearEmpty() {
    mux.forEach(
      (dst, value) {
        value.removeWhere(
          (key, value) {
            return value.usingList.isEmpty;
          },
        );
      },
    );

    mux.removeWhere(
      (key, value) {
        return value.isEmpty;
      },
    );
  }

  Future<RRSSocket> connect(host, int port) async {
    if (!transportClient1.isMux) {
      return await transportClient1.connect(host, port);
    }

    String dst = host + ":" + port.toString();
    late MuxInfo muxInfo;

    var isAssigned = false;

    clearEmpty();

    if (mux.containsKey(dst)) {
      mux[dst]!.forEach(
        (key, value) {
          if (value.usingList.length < transportClient1.maxThread) {
            muxInfo = value;
            isAssigned = true;
            return;
          }
        },
      );
    } else {
      mux[dst] = {};
    }

    if (!isAssigned) {
      muxInfoID += 1;
      muxInfo = MuxInfo(
          rrsSocket: await transportClient1.connect(host, port),
          muxInfoID: muxInfoID,
          muxPasswordSha224: muxPasswordSha224);
      mux[dst]![muxInfoID] = muxInfo;
    }

    muxInfo.id += 1;
    var temp = RRSSocketMux(
        threadID: muxInfo.id,
        muxInfo: muxInfo,
        muxPasswordSha224: muxPasswordSha224);
    muxInfo.usingList[muxInfo.id] = temp;
    return temp;
  }
} //}}}

class RRSServerSocketMux extends RRSServerSocket {
  //{{{
  late RRSServerSocket rrsServerSocket;
  List<int> muxPasswordSha224;

  RRSServerSocketMux(
      {required this.rrsServerSocket, required this.muxPasswordSha224})
      : super(serverSocket: rrsServerSocket.serverSocket);

  @override
  void listen(void Function(RRSSocket rrsSocket)? onData,
      {Function? onError, void Function()? onDone}) {
    super.listen((rrsSocket) {
      var muxInfo = MuxInfo(
          rrsSocket: rrsSocket,
          muxInfoID: 0,
          muxPasswordSha224: muxPasswordSha224);
      muxInfo.newConnection = onData;
    }, onError: onError, onDone: onDone);
  }

  @override
  List get streamSubscription => rrsServerSocket.streamSubscription;

  @override
  Future<void> clearListen() async {
    await rrsServerSocket.clearListen();
  }

  @override
  Future<void> close() async {
    await rrsServerSocket.close();
  }
} //}}}

class MuxServer {
  //{{{
  TransportServer1 transportServer1;
  List<int> muxPasswordSha224 = [];

  MuxServer({
    required this.transportServer1,
  }) {
    if (transportServer1.isMux) {
      if (transportServer1.muxPassword == '') {
        throw "muxPassword can not be null.";
      }
      muxPasswordSha224 = sha224
          .convert(transportServer1.muxPassword.codeUnits)
          .toString()
          .codeUnits;
    }
  }

  Future<RRSServerSocket> bind(address, int port) async {
    var res = await transportServer1.bind(address, port);
    if (!transportServer1.isMux) {
      return res;
    }
    return RRSServerSocketMux(
        rrsServerSocket: res, muxPasswordSha224: muxPasswordSha224);
  }
} //}}}
