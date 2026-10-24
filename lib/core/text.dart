/// "1 item", "9 items".
String plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
