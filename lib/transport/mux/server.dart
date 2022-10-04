import 'dart:typed_data';

import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/mux/client.dart';
import 'package:proxy/utils/utils.dart';
import 'package:quiver/collection.dart';

class MuxServerHandler extends MuxClientHandler {
  bool isFake = false;
  void Function(RRSSocket rrsSocket)? newConnection;

  MuxServerHandler({required super.rrsSocket, required super.muxPasswordSha224})
      : super(muxID: 0);

  @override
  void init() {
    rrsSocket.listen((data) {
      content += data;
      if (!isAuth) {
        if (content.length < 57) {
          // 56 + 1
          return;
        }
        var pwd = content.sublist(0, 56);
        if (!listsEqual(pwd, muxPasswordSha224)) {
          isFake = true;
        } else {
          var version = content[56];
          if (version != muxVersion) {
            // TODO
          }
          content = content.sublist(57);
        }
        isAuth = true;
      }
      handle();
    }, onDone: () async {
      await closeAll();
    }, onError: (e) async {
      await closeAll();
    });

    rrsSocket.done.then((value) {
      rrsSocket.clearListen();
    }, onError: (e) {
      rrsSocket.clearListen();
    });
  }

  @override
  void handle() {
    //{{{
    if (isFake) {
      // TODO
      throw 'todo';
    }
    if (content.length < 9) {
      // 1 + 8
      return;
    }

    RRSSocketMux2 dstSocket;
    if (currentThreadID == 0) {
      var threadID = content[0];
      currentThreadID = threadID;
      if (!usingList.containsKey(threadID)) {
        var temp = RRSSocketMux2(
          muxClientHandler: this,
        );
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
