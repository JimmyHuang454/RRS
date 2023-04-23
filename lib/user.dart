class Traffic {
  int uplink = 0;
  int downlink = 0;
}

class User {
  int lastUpdateTimeStamp = DateTime.now().millisecondsSinceEpoch;
  Traffic traffic = Traffic();
  int linkCount = 0;

  void addUplink(int count) {
    traffic.uplink += count;
    lastUpdateTimeStamp = DateTime.now().millisecondsSinceEpoch;
  }

  void addDownlink(int count) {
    traffic.downlink += count;
    lastUpdateTimeStamp = DateTime.now().millisecondsSinceEpoch;
  }

  void clearTraffic() {
    traffic.downlink = 0;
    traffic.uplink = 0;
  }
}
