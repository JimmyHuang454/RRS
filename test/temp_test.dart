import 'dart:async';
import 'package:async/async.dart';

import 'package:proxy/utils/utils.dart';
import 'package:test/test.dart';

void main() {
  var fastOpenStream = StreamController<int>.broadcast(sync: true);
  var fastOpenQueue = StreamQueue<int>(fastOpenStream.stream);
  void p() async {
    devPrint(await fastOpenQueue.next);
  }

  test('temp test.', () async {
    for (var i = 0; i < 10; ++i) {
      p();
    }

    devPrint(fastOpenQueue.eventsDispatched);
    await delay(2);

    for (var i = 0; i < 10; ++i) {
      fastOpenStream.add(i);
    devPrint(fastOpenQueue.eventsDispatched);
      await delay(1);
    }
  });
}
