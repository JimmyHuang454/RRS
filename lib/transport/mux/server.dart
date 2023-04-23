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
            throw 'todo';
          }
          content = content.sublist(57);
        }
        isAuth = true;
      }
      handle();
    }, onDone: () {
      closeAll();
    }, onError: (e) {
      devPrint('mux server listen: $e');
      closeAll();
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

      var temp = content.sublist(1, 9);
      Uint8List byteList = Uint8List.fromList(temp);
      ByteData byteData = ByteData.sublistView(byteList);
      currentLen = byteData.getUint64(0, Endian.big);

      content = content.sublist(9);
    } else {
      dstSocket = usingList[currentThreadID]!;
    }

    if (currentLen == 0) {
      dstSocket.onDone();
    } else {
      if (content.length < currentLen) {
        return;
      }
      dstSocket.onData(Uint8List.fromList(content.sublist(0, currentLen)));
      content = content.sublist(currentLen);
    }

    currentThreadID = 0;
    handle();
  } //}}}
}
