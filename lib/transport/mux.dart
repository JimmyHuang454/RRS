import 'dart:async';

import 'package:proxy/transport/client/base.dart';
import 'package:crypto/crypto.dart';
import 'package:proxy/transport/mux/client.dart';
import 'package:proxy/transport/mux/server.dart';
import 'package:proxy/transport/server/base.dart';
import 'package:proxy/utils/utils.dart';

class MuxClient {
  //{{{
  Map<String, Map<int, MuxClientHandler>> mux = {};

  int muxIDCount = 0;
  int paddingLen = -1;

  TransportClient transportClient;
  List<int> muxPasswordSha224 = [];

  MuxClient({required this.transportClient}) {
    if (transportClient.isMux) {
      if (transportClient.muxPassword == '') {
        throw "muxPassword can not be null.";
      }
      muxPasswordSha224 = sha224
          .convert(transportClient.muxPassword.codeUnits)
          .toString()
          .codeUnits;
    }

    paddingLen = getValue(transportClient.config, 'mux.paddingLen', -1);
  }

  void clearEmpty() {
    mux.forEach(
      (dst, value) {
        value.removeWhere(
          (key2, value2) {
            var isClosed = value2.isAllDone &&
                value2.usingList.length >= transportClient.maxThread &&
                !value2.isClosed;
            if (isClosed) {
              value2.rrsSocket.close();
              logger.info(
                  'muxID: ${value2.muxID}(including ${value2.usingList.length} done link) closed. Remainning ${value.length} links. ');
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
    if (!transportClient.isMux) {
      return await transportClient.connect(host, port);
    }

    String dst = host + ":" + port.toString();
    late MuxClientHandler muxInfo;

    muxIDCount += 1;
    var muxID = muxIDCount;

    clearEmpty();

    var isAssigned = false;
    if (mux.containsKey(dst)) {
      mux[dst]!.forEach(
        (key, value) {
          if (value.usingList.length < transportClient.maxThread &&
              !isAssigned &&
              !value.isClosed) {
            muxInfo = value;
            isAssigned = true;
          }
        },
      );
    } else {
      mux[dst] = {};
    }

    if (!isAssigned) {
      muxInfo = MuxClientHandler(
          rrsSocket: await transportClient.connect(host, port),
          muxID: muxID,
          muxPasswordSha224: muxPasswordSha224);
      mux[dst]![muxID] = muxInfo;
      muxInfo.init();
    }
    var res = RRSSocketMux2(muxClientHandler: muxInfo);
    logger.info(
        '$dst ${muxInfo.muxID}/${mux[dst]!.length} ${res.threadID}/${muxInfo.usingList.length}');
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
      muxInfo.newConnection = onData;
      muxInfo.init();
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
  TransportServer transportServer1;
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
