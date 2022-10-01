import 'dart:async';
import 'dart:typed_data';

import 'package:proxy/transport/client/base.dart';
import 'package:crypto/crypto.dart';
import 'package:proxy/transport/mux/client.dart';
import 'package:proxy/transport/mux/server.dart';
import 'package:proxy/transport/server/base.dart';

class MuxClient {
  //{{{
  Map<String, Map<int, MuxClientHandler>> mux = {};

  int muxIDCount = 0;

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
          (key2, value2) {
            var isClosed = value2.isAllDone &&
                value2.usingList.length >= transportClient1.maxThread;
            if (isClosed) {
              value2.rrsSocket.close();
              print(
                  'link $key2 closed. ${value2.usingList.length} -----------');
            }
            return isClosed;
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
    late MuxClientHandler muxInfo;

    print('1 $mux');
    clearEmpty();
    print('2 $mux');

    var isAssigned = false;
    if (mux.containsKey(dst)) {
      mux[dst]!.forEach(
        (key, value) {
          if (value.usingList.length < transportClient1.maxThread &&
              !isAssigned) {
            muxInfo = value;
            isAssigned = true;
          }
        },
      );
    } else {
      mux[dst] = {};
    }

    if (!isAssigned) {
      muxIDCount += 1;
      muxInfo = MuxClientHandler(
          rrsSocket: await transportClient1.connect(host, port),
          muxID: muxIDCount,
          muxPasswordSha224: muxPasswordSha224);
      muxInfo.init();
      mux[dst]![muxIDCount] = muxInfo;
    }
    print('3 $mux');
    var res = RRSSocketMux2(muxClientHandler: muxInfo);
    print('$dst ${muxInfo.muxID} ${res.threadID}/${muxInfo.usingList.length}');
    return res;
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
    rrsServerSocket.listen((rrsSocket) {
      var muxInfo = MuxServerHandler(
          rrsSocket: rrsSocket, muxPasswordSha224: muxPasswordSha224);
      muxInfo.init();
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
    var temp = await transportServer1.bind(address, port);
    if (!transportServer1.isMux) {
      return temp;
    }
    return RRSServerSocketMux(
        rrsServerSocket: temp, muxPasswordSha224: muxPasswordSha224);
  }
} //}}}
