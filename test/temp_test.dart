import 'dart:async';

import 'package:proxy/utils/utils.dart';
import 'package:test/test.dart';

void main() {
  test('temp test.', () async {
    // Create Stream
    StreamController<int> client = StreamController<int>();
    StreamController<int> server = StreamController<int>();
    int nr = 60;
// add event/data to stream controller using sink
    client.stream.listen((data) {
      devPrint('client.');
      devPrint(data);
    }, onDone: () {
      devPrint('client ondone.');
      server.sink.close();
    });

    server.sink.add(nr);

    server.stream.listen((data) {
      devPrint('server.');
      client.sink.add(data);
      client.sink.close();
    }, onDone: () {
      devPrint('server ondone.');
    });

    client.done.then(
      (value) {
        devPrint('client done.');
      },
    );

    server.done.then(
      (value) {
        devPrint('server done.');
      },
    );
  });
}
