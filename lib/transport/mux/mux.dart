import 'package:proxy/transport/client/base.dart';
import 'package:proxy/transport/mux/client.dart';

class MuxHandler {
  RRSSocket rrsSocket;
  List<int> muxPasswordSha224;

  int muxID;
  Map<int, RRSSocketMux2> usingList = {};
  bool isAuth = false;
  final muxVersion = 0;
  int currentThreadID = 0;
  int currentLen = 0;
  int addedLen = 0;
  List<int> content = [];

  bool isAllDone = false;

  MuxHandler(
      {required this.rrsSocket,
      required this.muxPasswordSha224,
      required this.muxID});
}
