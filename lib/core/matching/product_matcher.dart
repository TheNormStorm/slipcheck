import 'product_normalizer.dart';

/// A product the matcher can choose from.
class ProductCandidate {
  const ProductCandidate({required this.id, required this.key, required this.displayName});
  final int id;

  /// The product's [NormalizedProduct.key].
  final String key;
  final String displayName;
}

/// A remembered mapping from a receipt text key to a product, optionally
/// limited to one store (store abbreviations differ).
class ProductAlias {
  const ProductAlias({required this.key, required this.productId, this.storeId});
  final String key;
  final int productId;
  final int? storeId;
}

enum MatchKind { barcode, storeAlias, alias, exact, fuzzy, none }

/// The alias key a printed barcode or PLU is remembered under, and whether
/// it only means something at one store. In-store codes for weighed or
/// packed-in-store goods (13 digits starting with 2, e.g. "2093870000000")
/// are store-specific; UPC/EAN barcodes and produce PLUs are the same at
/// every store.
({String key, bool storeOnly}) codeAlias(String code) =>
    (key: 'code:$code', storeOnly: code.length >= 12 && code.startsWith('2'));

class MatchResult {
  const MatchResult(this.kind, {this.product, this.score = 0});
  final MatchKind kind;
  final ProductCandidate? product;
  final double score;

  /// True when the match is certain enough to apply without asking.
  bool get isConfident =>
      kind == MatchKind.barcode ||
      kind == MatchKind.storeAlias ||
      kind == MatchKind.alias ||
      kind == MatchKind.exact;
}

/// Finds which known product a receipt line refers to. Pure and synchronous:
/// callers load candidates and aliases from the database first.
class ProductMatcher {
  ProductMatcher(List<ProductCandidate> products, List<ProductAlias> aliases,
      {this.fuzzyThreshold = 0.72})
      : _byId = {for (final p in products) p.id: p},
        _byKey = {for (final p in products) p.key: p},
        _normalized = {for (final p in products) p.id: normalizeProduct(p.key)},
        _aliases = aliases;

  final Map<int, ProductCandidate> _byId;
  final Map<String, ProductCandidate> _byKey;
  final Map<int, NormalizedProduct> _normalized;
  final List<ProductAlias> _aliases;
  final double fuzzyThreshold;

  MatchResult match(String rawText, {int? storeId, String? code}) {
    final norm = normalizeProduct(rawText);
    final key = norm.key;

    if (code != null) {
      final c = codeAlias(code);
      for (final a in _aliases) {
        if (a.key == c.key &&
            (a.storeId == null || a.storeId == storeId) &&
            _byId.containsKey(a.productId)) {
          return MatchResult(MatchKind.barcode, product: _byId[a.productId], score: 1);
        }
      }
    }

    if (storeId != null) {
      for (final a in _aliases) {
        if (a.storeId == storeId && a.key == key && _byId.containsKey(a.productId)) {
          return MatchResult(MatchKind.storeAlias, product: _byId[a.productId], score: 1);
        }
      }
    }
    final exact = _byKey[key];
    if (exact != null) return MatchResult(MatchKind.exact, product: exact, score: 1);
    for (final a in _aliases) {
      if (a.storeId == null && a.key == key && _byId.containsKey(a.productId)) {
        return MatchResult(MatchKind.alias, product: _byId[a.productId], score: 1);
      }
    }

    ProductCandidate? best;
    var bestScore = 0.0;
    for (final entry in _normalized.entries) {
      final other = entry.value;
      // Different sizes are different products, even with the same name.
      if (norm.sizeValue != null && other.sizeValue != null && !norm.sameSize(other)) {
        continue;
      }
      final score = similarity(norm.name, other.name);
      if (score > bestScore) {
        bestScore = score;
        best = _byId[entry.key];
      }
    }
    if (best != null && bestScore >= fuzzyThreshold) {
      return MatchResult(MatchKind.fuzzy, product: best, score: bestScore);
    }
    return const MatchResult(MatchKind.none);
  }
}

/// Sørensen–Dice similarity of character bigrams, 0..1, ignoring spaces.
double similarity(String a, String b) {
  if (a == b) return 1;
  final ga = _bigrams(a), gb = _bigrams(b);
  if (ga.isEmpty || gb.isEmpty) return 0;
  final counts = <String, int>{};
  for (final g in ga) {
    counts[g] = (counts[g] ?? 0) + 1;
  }
  var overlap = 0;
  for (final g in gb) {
    final c = counts[g] ?? 0;
    if (c > 0) {
      overlap++;
      counts[g] = c - 1;
    }
  }
  return 2 * overlap / (ga.length + gb.length);
}

List<String> _bigrams(String s) {
  final t = s.replaceAll(' ', '');
  return [for (var i = 0; i < t.length - 1; i++) t.substring(i, i + 2)];
}
