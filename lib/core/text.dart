/// "1 item", "9 items".
String plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

/// A receipt's all-caps name in sentence case, for running text:
/// "PRIME SHAVED STEAK" → "Prime shaved steak". Names already in mixed case
/// are left alone, as someone typed them that way.
String sentenceCase(String name) {
  final t = name.trim();
  if (t.isEmpty || t != t.toUpperCase()) return t;
  // Litres keep their capital L ("1L", "2.5 L"); other units read fine lower.
  final lower = t.toLowerCase().replaceAllMapped(RegExp(r'(\d\s?)l\b'), (m) => '${m[1]}L');
  return lower[0].toUpperCase() + lower.substring(1);
}
