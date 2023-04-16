Map<String, dynamic> defaultSetting = {
  "inStream": {
    "default": {"protocol": "tcp"},
    "tcp": {"protocol": "tcp"},
    "ws": {"protocol": "ws"}
  },
  "outStream": {
    "default": {"protocol": "tcp"},
    "tcp": {"protocol": "tcp"},
    "tls": {
      "protocol": "tcp",
      "tls": {
        "enabled": true,
      },
    },
    "tls_tcp": {
      "protocol": "tcp",
      "tls": {
        "enabled": true,
      },
    },
    "tls_ws": {
      "protocol": "ws",
      "tls": {"enabled": true},
      "setting": {"path": "uif_trojan"}
    }
  },
  "outbounds": {
    "default": {"protocol": "freedom", "outStream": "tcp"},
    "freedom": {"protocol": "freedom", "outStream": "tcp"},
  },
  "dns": {
    "txDOH": {"type": "doh", "address": "https://doh.pub/dns-query"},
  },
  // "routes": {
  //   // key 'comment' is to fix type error. It's not really useful.
  //   "default": {
  //     "rules": [
  //       {
  //         "outbound": ["default"]
  //       }
  //     ],
  //     'comment': {}
  //   },
  //   "freedom": {
  //     "rules": [
  //       {
  //         "outbound": ["default"]
  //       }
  //     ],
  //     'comment': {}
  //   }
  // }
};
