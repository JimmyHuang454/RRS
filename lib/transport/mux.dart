import 'package:proxy/transport/client/base.dart';

class MuxInfo {
  int id = 0;
  int currentThreadID = 0;
  int currentLen = 0;
  int addedLen = 0;
  bool isListened = false;
  dynamic socket;
  Map<int, RRSSocketMux> usingList = {};

  MuxInfo({required this.socket});

  List<int> content = [];
}
