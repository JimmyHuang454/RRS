import 'package:uuid/uuid.dart';

class Traffic {
  int uplink = 0;
  int downlink = 0;
}

class User {
  String id;

  int lastUpdateTimeStamp = DateTime.now().millisecondsSinceEpoch;
  int uplinkByte = 0;
  int downlinkByte = 0;
  bool isPermitted = false;

  User({this.id = ''}) {
    if (id == '') {
      id = Uuid().v1();
    }
  }

  String getAllInfo() {
    return '';
  }

  void addUplink(int nr) {
    uplinkByte += nr;
    lastUpdateTimeStamp = DateTime.now().millisecondsSinceEpoch;
  }

  void addDownlink(int nr) {
    downlinkByte += nr;
    lastUpdateTimeStamp = DateTime.now().millisecondsSinceEpoch;
  }

  void clearTraffic() {
    uplinkByte = 0;
    downlinkByte = 0;
  }

  void disable() {
    isPermitted = false;
  }

  void enable() {
    isPermitted = true;
  }
}
