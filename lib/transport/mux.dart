import 'dart:async';
import 'dart:typed_data';

import 'package:proxy/transport/client/base.dart';
import 'package:crypto/crypto.dart';
import 'package:proxy/transport/server/base.dart';
import 'package:quiver/collection.dart';

class MuxHandler {
  //{{{
  int muxInfoID;

  int id = 0;
  int version = 0;
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
  bool isClosed = false;
  bool isAllDone = false;

  MuxHandler(
      {required this.rrsSocket,
      required this.muxInfoID,
      required this.muxPasswordSha224}) {
    rrsSocket.listen((event) async {
      content += event;
      if (!isAuth) {
        if (content.length < 57) {
          // 56 + 1
          return;
        }
        var pwd = content.sublist(0, 56);
        if (!listsEqual(pwd, muxPasswordSha224)) {
          isFake = true;
        } else {
          version = content[56];
          content = content.sublist(57);
        }
        isAuth = true;
      }

      if (isFake) {
        // TODO: pass to fake tunnel.
        return;
      }

      handle();
    }, onDone: () {
      isClosed = true;
      closeAll();
    }, onError: (e) {
      isClosed = true;
      closeAll();
    });
  }

  void handle() async {
    //{{{
    if (content.length < 9) {
      // 1 + 8
      return;
    }

    RRSSocketMux dstSocket;
    if (currentThreadID == 0) {
      var threadID = content[0];
      currentThreadID = threadID;
      if (!usingList.containsKey(threadID)) {
        var temp = RRSSocketMux(
            threadID: threadID,
            muxInfo: this,
            rrsSocket: rrsSocket,
            muxPasswordSha224: muxPasswordSha224);
        usingList[threadID] = temp;
        newConnection!(temp);
      }
      dstSocket = usingList[threadID]!;

      Uint8List byteList = Uint8List.fromList(content.sublist(1, 9));
      ByteData byteData = ByteData.sublistView(byteList);
      currentLen = byteData.getUint64(0, Endian.big);
      addedLen = 0;

      content = content.sublist(9);
    } else {
      dstSocket = usingList[currentThreadID]!;
    }

    if (currentLen == 0) {
      onDone(currentThreadID);
    } else {
      var handleLen = currentLen - addedLen;
      if (content.length < handleLen) {
        handleLen = content.length;
      }
      dstSocket.onData2!(Uint8List.fromList(content.sublist(0, handleLen)));
      addedLen += handleLen;
      content = content.sublist(handleLen);
    }

    if (addedLen == currentLen) {
      currentThreadID = 0;
    }
    handle();
  } //}}}

  void closeAll() {
    if (isFake) {
      // TODO: pass to fake tunnel.
    } else {
      usingList.forEach(
        (key, value) {
          onDone(key);
        },
      );
    }
  }

  void onDone(int threadID) {
    if (!usingList.containsKey(threadID)) {
      return;
    }
    RRSSocketMux dstSocket;
    dstSocket = usingList[threadID]!;

    if (dstSocket.onDone2 != null && !dstSocket.readClosed) {
      dstSocket.onDone2!();
    }
    dstSocket.readClosed = true;

    triggerDone(dstSocket);
  }

  void triggerDone(RRSSocketMux dstSocket) {
    if (dstSocket.isDone) {
      return;
    }

    if (dstSocket.writeClosed && dstSocket.readClosed) {
      dstSocket.isDone = true;
      dstSocket.c.complete('ok');
    }

    isAllDone = true;
    usingList.forEach(
      (key, value) {
        if (!value.isDone) {
          isAllDone = false;
        }
      },
    );

    if (!isAllDone || !isClosed) {
      return;
    }

    rrsSocket.close();
  }

  void close(int threadID) {
    if (!usingList.containsKey(threadID)) {
      return;
    }

    RRSSocketMux dstSocket;
    dstSocket = usingList[threadID]!;

    if (!dstSocket.writeClosed) {
      dstSocket.add([]);
    }
    dstSocket.writeClosed = true;

    triggerDone(dstSocket);
  }
} //}}}

class RRSSocketMux extends RRSSocketBase {
  //{{{
  int threadID;
  MuxHandler muxInfo;
  List<int> muxPasswordSha224;

  void Function(Uint8List event)? onData2;
  Function? onError2;
  void Function()? onDone2;

  bool writeClosed = false;
  bool readClosed = false;
  bool isDone = false;
  int version = 0;
  final c = Completer();

  RRSSocketMux(
      {required this.threadID,
      required this.muxInfo,
      required super.rrsSocket,
      required this.muxPasswordSha224});

  @override
  void add(List<int> data) {
    if (writeClosed) {
      return;
    }

    List<int> temp = [threadID];
    if (!muxInfo.isAuth) {
      temp = [version, threadID];
      temp = List.from(muxPasswordSha224)..addAll(temp);
      muxInfo.isAuth = true;
    }
    temp += Uint8List(8)
      ..buffer.asByteData().setUint64(0, data.length, Endian.big);
    temp += data;
    rrsSocket.add(temp);
  }

  @override
  void close() {
    muxInfo.close(threadID);
  }

  @override
  Future<dynamic> get done => c.future;

  @override
  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    onData2 = onData;
    onError2 = onError2;
    onDone2 = onDone;
  }
} //}}}

class MuxClient {
  //{{{
  Map<String, Map<int, MuxHandler>> mux = {};

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
            if (value.isAllDone) {
              value.rrsSocket.close();
            }
            return value.isAllDone;
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
    late MuxHandler muxInfo;

    var isAssigned = false;

    clearEmpty();

    if (mux.containsKey(dst)) {
      mux[dst]!.forEach(
        (key, value) {
          if (value.usingList.length < transportClient1.maxThread &&
              !isAssigned) {
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
      muxInfo = MuxHandler(
          rrsSocket: await transportClient1.connect(host, port),
          muxInfoID: muxInfoID,
          muxPasswordSha224: muxPasswordSha224);
      mux[dst]![muxInfoID] = muxInfo;
    }

    muxInfo.id += 1;
    var temp = RRSSocketMux(
        threadID: muxInfo.id,
        muxInfo: muxInfo,
        rrsSocket: muxInfo.rrsSocket,
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
      var muxInfo = MuxHandler(
          rrsSocket: rrsSocket,
          muxInfoID: 0,
          muxPasswordSha224: muxPasswordSha224);
      muxInfo.newConnection = onData;
    }, onError: onError, onDone: onDone);
  }

  @override
  List get streamSubscription => rrsServerSocket.streamSubscription;

  @override
  void clearListen() {
    rrsServerSocket.clearListen();
  }

  @override
  void close() {
    rrsServerSocket.close();
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
