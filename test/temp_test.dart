import 'dart:async';
import 'dart:io';
import 'package:async/async.dart';

import 'package:proxy/utils/utils.dart';
import 'package:test/test.dart';

void main() {
  test('temp test.', () async {

    var temp = Future.delayed(Duration(seconds: 2));
    temp.then((val){
      print('1');
    });

    temp.then((val){
      print('2');
    });

    await temp;
  });
}
