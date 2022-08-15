
dynamic getValue(Map<String, dynamic> map, String key, dynamic defaultValue) {
  var temp = key.split('.');
  dynamic deep = map;
  for (var i = 0, len = temp.length; i < len; ++i) {
    try {
      if (deep.containsKey(temp[i])) {
        deep = deep[temp[i]];
        continue;
      }
    } catch (_) {}
    return defaultValue;
  }
  return deep;
}

int indexOfElements(List<int> old, List<int> n, [int start = 0]) {
  var i = start;
  for (; i < old.length && i + 3 < old.length; ++i) {
    var j = 0;
    for (; j < n.length; ++j) {
      if (old[i + j] != n[j]) {
        break;
      }
    }
    if (j == n.length) {
      return i;
    }
  }
  return -1;
}

void devPrint(msg){
  print(msg);
}
