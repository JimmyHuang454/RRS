import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/mux/client.dart';
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
    }, onDone: () {
      closeAll();
    }, onError: (e) {
      closeAll();
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
    if (content.length < 9) {
      // 1 + 8
      return;
    }

    if (currentThreadID == 0) {
      var threadID = content[0];
      currentThreadID = threadID;
      if (!usingList.containsKey(threadID)) {
        var temp = RRSSocketMux2(
          muxClientHandler: this,
        );
        usingList[threadID] = temp;
        newConnection!(temp);
      } else {
        // should not happen.
      }
      currentThreadID = 0;
    }

    super.handle();
  } //}}}
}
