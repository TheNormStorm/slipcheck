/// A product name reduced to a comparable form.
class NormalizedProduct {
  const NormalizedProduct({
    required this.name,
    this.sizeValue,
    this.sizeUnit,
    this.packCount,
  });

  /// Lowercase name without size, abbreviations expanded: "milk 2%".
  final String name;

  /// Size per unit in [sizeUnit]: 1000 for a 1 L carton.
  final double? sizeValue;

  /// 'ml' or 'g'.
  final String? sizeUnit;

  /// 6 for "6x355ml".
  final int? packCount;

  String? get sizeLabel {
    if (sizeValue == null) return null;
    final v = sizeValue! == sizeValue!.roundToDouble()
        ? sizeValue!.toInt().toString()
        : sizeValue!.toStringAsFixed(1);
    return '${packCount != null ? '${packCount}x' : ''}$v$sizeUnit';
  }

  /// The match key: "milk 2% 1000ml".
  String get key => sizeLabel == null ? name : '$name $sizeLabel';

  bool sameSize(NormalizedProduct other) =>
      sizeValue == other.sizeValue &&
      sizeUnit == other.sizeUnit &&
      packCount == other.packCount;
}

const _unitFactors = <String, (String, double)>{
  'ml': ('ml', 1), 'millilitre': ('ml', 1), 'millilitres': ('ml', 1),
  'milliliter': ('ml', 1), 'milliliters': ('ml', 1),
  'cl': ('ml', 10),
  'l': ('ml', 1000), 'lt': ('ml', 1000), 'ltr': ('ml', 1000),
  'litre': ('ml', 1000), 'litres': ('ml', 1000),
  'liter': ('ml', 1000), 'liters': ('ml', 1000),
  'g': ('g', 1), 'gr': ('g', 1), 'gm': ('g', 1), 'grams': ('g', 1), 'gram': ('g', 1),
  'kg': ('g', 1000), 'kgs': ('g', 1000), 'kilo': ('g', 1000), 'kilos': ('g', 1000),
  'lb': ('g', 453.592), 'lbs': ('g', 453.592),
  'oz': ('g', 28.3495),
};

/// Receipt abbreviations → words. Extend as real receipts show new ones.
const _abbreviations = <String, String>{
  'org': 'organic', 'orgnc': 'organic',
  'choc': 'chocolate', 'chkn': 'chicken', 'chk': 'chicken',
  'brd': 'bread', 'wht': 'white', 'ww': 'whole wheat', 'wholewheat': 'whole wheat',
  'bnls': 'boneless', 'sknls': 'skinless', 'grd': 'ground', 'bf': 'beef',
  'yog': 'yogurt', 'yogh': 'yogurt', 'yoghurt': 'yogurt', 'ygt': 'yogurt',
  'veg': 'vegetable', 'vegs': 'vegetables', 'mlk': 'milk', 'chs': 'cheese',
  'ched': 'cheddar', 'tom': 'tomato', 'toms': 'tomatoes', 'pot': 'potato',
  'bana': 'banana', 'bananas': 'banana', 'apples': 'apple', 'eggs': 'egg',
  'lg': 'large', 'med': 'medium', 'sm': 'small', 'pk': 'pack',
  'frz': 'frozen', 'frzn': 'frozen', 'hmo': 'homo', 'homogenized': 'homo',
};

final _packSize = RegExp(
    r'(\d{1,3})\s*x\s*(\d+(?:[.,]\d+)?)\s*([a-z]+)\b');
final _size = RegExp(r'(\d+(?:[.,]\d+)?)\s*([a-z]+)\b');

/// Normalises a receipt or user-typed product name so that
/// "MILK 2% 1L" and "Milk 2% 1 litre" produce the same [NormalizedProduct.key].
NormalizedProduct normalizeProduct(String raw) {
  var text = raw.toLowerCase();
  // Keep % and decimal points/commas inside numbers; everything else is a separator.
  text = text.replaceAll(RegExp(r'[^a-z0-9%.,]+'), ' ');
  text = text.replaceAll(RegExp(r'(?<!\d)[.,]|[.,](?!\d)'), ' ');

  double? sizeValue;
  String? sizeUnit;
  int? packCount;

  final pack = _packSize.firstMatch(text);
  if (pack != null && _unitFactors.containsKey(pack.group(3))) {
    final (unit, factor) = _unitFactors[pack.group(3)]!;
    packCount = int.parse(pack.group(1)!);
    sizeValue = _round(_num(pack.group(2)!) * factor);
    sizeUnit = unit;
    text = text.replaceRange(pack.start, pack.end, ' ');
  } else {
    for (final m in _size.allMatches(text)) {
      if (!_unitFactors.containsKey(m.group(2))) continue;
      final (unit, factor) = _unitFactors[m.group(2)]!;
      sizeValue = _round(_num(m.group(1)!) * factor);
      sizeUnit = unit;
      text = text.replaceRange(m.start, m.end, ' ');
      break;
    }
  }

  final words = <String>[];
  for (final token in text.split(' ')) {
    if (token.isEmpty) continue;
    // Drop SKU / PLU codes; keep short numbers like the "2" in "2 %".
    if (RegExp(r'^\d{4,}$').hasMatch(token)) continue;
    words.add(_abbreviations[token] ?? token);
  }
  // "2 %" → "2%"
  final name =
      words.join(' ').replaceAllMapped(RegExp(r'(\d) %'), (m) => '${m[1]}%');

  return NormalizedProduct(
    name: name,
    sizeValue: sizeValue,
    sizeUnit: sizeUnit,
    packCount: packCount,
  );
}

double _num(String s) => double.parse(s.replaceAll(',', '.'));
double _round(double v) => (v * 10).roundToDouble() / 10;
