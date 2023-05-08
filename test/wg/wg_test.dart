
import 'package:cryptography/cryptography.dart';
import 'package:test/test.dart';

import 'package:proxy/utils/utils.dart';

final algorithm = Cryptography.instance.x25519();

void main() {
  test('wg Initiator', () async {
    final algorithm = X25519();

    // We need the private key pair of Alice.
    final aliceKeyPair = await algorithm.newKeyPair();

    // We need only public key of Bob.
    final bobKeyPair = await algorithm.newKeyPair();
    final bobPublicKey = await bobKeyPair.extractPublicKey();

    // We can now calculate a 32-byte shared secret key.
    final sharedSecretKey = await algorithm.sharedSecretKey(
      keyPair: aliceKeyPair,
      remotePublicKey: bobPublicKey,
    );
    devPrint(await sharedSecretKey.extractBytes());
  });
}
