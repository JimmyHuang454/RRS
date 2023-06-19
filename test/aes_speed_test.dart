import 'package:cryptography/cryptography.dart';
import 'package:test/test.dart';
import 'package:cryptography/helpers.dart';
import 'package:proxy/utils/utils.dart';

void main() {
  test('AES speed.', () async {
    var lenMB = 3;
    var times = 10;

    var time2 = 0;

    var buffer = randomBytes(1000000 * lenMB);
    final aes = AesGcm.with256bits(nonceLength: 64);
    devPrint(buffer.length);

    for (var i = 0; i < times; i++) {
      var pwd = randomBytes(32);
      var iv = randomBytes(64);
      var secretKey = await aes.newSecretKeyFromBytes(pwd);
      Stopwatch createdTime = Stopwatch()..start();
      var secretBox =
          await aes.encrypt(buffer, secretKey: secretKey, nonce: iv);
      createdTime.stop();
      var sec = createdTime.elapsedMilliseconds;
      time2 += sec;
    }
    devPrint(time2);
    devPrint((lenMB * times) / (time2 / 1000));
  });
}
