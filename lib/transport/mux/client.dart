import 'dart:async';
import 'dart:typed_data';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/mux/mux.dart';
import 'package:proxy/utils/utils.dart';

class MuxClientHandler extends MuxHandler {
  int threadIDCount = 0;

  MuxClientHandler(
      {required super.rrsSocket,
      required super.muxPasswordSha224,
      required super.muxID});

  void init() {
    rrsSocket.listen((data) {
      content += data;
      handle();
    }, onDone: () {
      closeAll();
    }, onError: (e) {
      closeAll();
    });

    rrsSocket.done.then((value) {
      closeAll();
      rrsSocket.clearListen();
    }, onError: (e) {
      closeAll();
      rrsSocket.clearListen();
    });
  }

  void closeAll() {
    rrsSocket.close();

    usingList.forEach(
      (key, value) {
        value.onDone();
      },
    );
  }

  void handle() {
    //{{{
    if (content.length < 9) {
      // 1 + 8
      return;
    }

    RRSSocketMux2 dstSocket;
    if (currentThreadID == 0) {
      var threadID = content[0];
      currentThreadID = threadID;
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
      dstSocket.onDone();
    } else {
      var handleLen = currentLen - addedLen;
      if (content.length < handleLen) {
        handleLen = content.length;
      }
      dstSocket.onData(Uint8List.fromList(content.sublist(0, handleLen)));
      addedLen += handleLen;
      content = content.sublist(handleLen);
    }

    if (addedLen == currentLen) {
      currentThreadID = 0;
    }
    handle();
  } //}}}
}

class RRSSocketMux2 extends RRSSocketBase {
  //{{{
  late int threadID;
  MuxClientHandler muxClientHandler;

  void Function(Uint8List event)? onData2;
  Function? onError2;
  void Function()? onDone2;

  bool writeClosed = false;
  bool readClosed = false;
  bool isDone = false;
  final c = Completer();

  RRSSocketMux2({required this.muxClientHandler})
      : super(rrsSocket: muxClientHandler.rrsSocket) {
    muxClientHandler.threadIDCount += 1;
    threadID = muxClientHandler.threadIDCount;
    muxClientHandler.usingList[threadID] = this;
  }

  void sendWithHeader(List<int> data) {
    List<int> temp = [threadID];
    if (!muxClientHandler.isAuth) {
      muxClientHandler.isAuth = true;
      temp = [muxClientHandler.muxVersion, threadID];
      temp = List.from(muxClientHandler.muxPasswordSha224)..addAll(temp);
    }
    temp += Uint8List(8)
      ..buffer.asByteData().setUint64(0, data.length, Endian.big);
    temp += data;
    rrsSocket.add(temp);
  }

  void completeDone() {
    if (!isDone && writeClosed && readClosed) {
      isDone = true;
      c.complete('ok');
    }

    muxClientHandler.isAllDone = true;
    muxClientHandler.usingList.forEach(
      (key, value) {
        if (!value.isDone) {
          muxClientHandler.isAllDone = false;
        }
      },
    );
  }

  void onData(Uint8List data) {
    if (onData2 != null && !readClosed) {
      onData2!(data);
    }
  }

  void onDone() {
    if (!readClosed) {
      readClosed = true;
      if (onDone2 != null) {
        onDone2!();
      }
    }
    completeDone();
  }

  @override
  void add(List<int> data) {
    if (writeClosed) {
      return;
    }
    sendWithHeader(data);
  }

  @override
  void close() {
    if (writeClosed) {
      return;
    }
    writeClosed = true;
    sendWithHeader([]);
    completeDone();
  }

  @override
  Future<dynamic> get done => c.future;

  @override
  void listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone}) {
    onData2 = onData;
    onError2 = onError;
    onDone2 = onDone;
  }

  // Inbound will clear listen after done, so if we can not let it clear mux link.
  @override
  void clearListen() {}
} //}}}
