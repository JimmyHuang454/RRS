import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:quiver/collection.dart';
import 'package:proxy/utils/utils.dart';
import 'package:proxy/inbounds/base.dart';
import 'package:crypto/crypto.dart';

final algorithm = Cryptography.instance.x25519();

class HandshakeInitiation {
  int messageType = 1;

  int senderIndex = 0;

  Uint8List unencryptedEphemeral;
  // Uint8List encryptedStatic;
  // Uint8List encryptedTimestamp;
  Uint8List mac1;
  Uint8List mac2;

  HandshakeInitiation(
      {required this.unencryptedEphemeral,
      required this.mac2,
      required this.mac1}){
    senderIndex = 0;
  }
}

class WGRequest extends Link {
  WGRequest({
    required super.client,
    required super.inboundStruct,
  }) {
    return;
  }
}

class TrojanIn extends InboundStruct {
  List<int> pwdSHA224 = [];
  String? password;
  String? tunnelAddress;
  int? tunnelPort;

  TrojanIn({required super.config})
      : super(protocolName: 'trojan', protocolVersion: '1') {
    password = getValue(config, 'setting.password', '');
    tunnelAddress = getValue(config, 'setting.tunnelAddress', '');
    tunnelPort = getValue(config, 'setting.tunnelPort', 0);
    if (inAddress == '' ||
        inPort == 0 ||
        password == '' ||
        tunnelAddress == '') {
      throw 'trojan required "address", "port", "tunnelAddress", "tunnelPort" and "password" in config.';
    }
    pwdSHA224 = sha224.convert(password!.codeUnits).toString().codeUnits;
  }

  @override
  Future<void> bind() async {
    var server = await getServer().bind(inAddress, inPort);

    server.listen((client) async {
      WGRequest(client: client, inboundStruct: this, );
    }, onError: (e) {
      print(e);
    }, onDone: () {});
  }
}
