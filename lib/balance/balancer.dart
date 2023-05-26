import 'package:proxy/obj_list.dart';
import 'package:proxy/outbounds/base.dart';
import 'package:proxy/utils/const.dart';
import 'package:proxy/utils/utils.dart';

class Balancer {
  Map<String, dynamic> config;

  DispatchType dispatchType = DispatchType.random;

  String tag = '';
  List<OutboundStruct> outbound = [];

  Balancer.load({this.config = const {}, required dynamic out}) {
    load(out);
  }

  void load(dynamic out) {
    List<String> outList = [];
    if (out.runtimeType == String) {
      outList.add(out as String);
    } else if (out.runtimeType == List) {
      for (var i = 0, len = out.length; i < len; ++i) {
        outList.add(out[i] as String);
      }
    } else {
      throw 'Unknow outbound.';
    }

    for (var i = 0, len = outList.length; i < len; ++i) {
      if (!outboundsList.containsKey(outList[i])) {
        throw 'There are no route tag named "$out".';
      }
      outbound.add(outboundsList[outList[i]]!);
    }

    if (outbound.isEmpty) {
      throw 'outbound can not be empty.';
    }
  }

  Balancer({required this.config}) {
    tag = getValue(config, 'tag', '');

    var out = getValue(config, 'outbound', '');
    if (out == '') {
      throw 'outbound can not be null.';
    }
    load(out);

    var type = getValue(config, 'dispatchType', 'random');
    if (type == 'random') {
      dispatchType = DispatchType.random;
    }
  }

  OutboundStruct dispatch() {
    var temp = DateTime.now().millisecond % outbound.length;
    return outbound[temp];
  }
}
