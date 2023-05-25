import 'package:proxy/obj_list.dart';
import 'package:proxy/outbounds/base.dart';
import 'package:proxy/utils/utils.dart';

class Balancer {
  Map<String, dynamic> config;

  String tag = '';
  List<OutboundStruct> outbound = [];

  Balancer({required this.config}) {
    tag = getValue(config, 'tag', '');

    var out = getValue(config, 'outbound', '');
    if (out == '') {
      throw 'outbound can not be null.';
    }

    List<String> outList = [];
    if (out.runtimeType == String) {
      outList += out;
    } else if (out.runtimeType == List) {
      for (var i = 0, len = out.length; i < len; ++i) {
        outList.add(out[i] as String);
      }
    } else {
      throw 'Unknow outbound.';
    }

    for (var i = 0, len = outList.length; i < len; ++i) {
      if (!outboundsList.containsKey(outList[i])) {
        throw 'There are no route tag named "${outbound[i]}".';
      }
      outbound.add(outboundsList[outList[i]]!);
    }
  }

  OutboundStruct dispatch() {
    return outbound[0];
  }
}
