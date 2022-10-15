Map<String, dynamic> defaultSetting = {
  "inStream": {
    "default": {"protocol": "tcp"},
    "tcp": {"protocol": "tcp"},
  },
  "outStream": {
    "default": {"protocol": "tcp"},
    "tcp": {"protocol": "tcp"}
  },
  "outbounds": {
    "default": {"protocol": "freedom", "outStream": "tcp"},
    "freedom": {"protocol": "freedom", "outStream": "tcp"}
  },
  "routes": {
    // "default": {
    //   "rules": [
    //     {
    //       "outbound": ["default"]
    //     }
    //   ]
    // },
    // "freedom": {
    //   "rules": [
    //     {
    //       "outbound": ["default"]
    //     }
    //   ]
    // }
  }
};
