class Traffic {
  int uplink = 0;
  int downlink = 0;
  int activeLinkCount = 0; // active link count
}

class User {
  int lastUpdateTimeStamp = DateTime.now().millisecondsSinceEpoch;
  Traffic traffic = Traffic();

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
