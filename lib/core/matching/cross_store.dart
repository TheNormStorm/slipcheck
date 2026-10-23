import 'product_matcher.dart' show similarity;
import 'product_normalizer.dart';

/// What the suggester needs to know about a product.
class ProductInfo {
  const ProductInfo({
    required this.id,
    required this.name,
    required this.storeIds,
    this.category,
  });

  final int id;
  final String name;
  final Set<int> storeIds;
  final String? category;
}

class MatchSuggestion {
  const MatchSuggestion(this.product, this.score);
  final ProductInfo product;
  final double score;
}

/// Products from other stores that are probably the same thing as [target]:
/// "MB LG BROWN CAGE FREE 18PK" at one store and "LARGE BROWN EGGS 18 CT"
/// at another. Only suggestions - the user confirms each link.
///
/// A candidate must never have been bought at a store where [target] was
/// (there they are two different products by definition), must not be in a
/// different category, and must not have a different size or pack count. It
/// is scored on name similarity after dropping short brand-ish tokens ("MB",
/// "365"), with a bonus when both name the same size.
List<MatchSuggestion> suggestSameProduct(
  ProductInfo target,
  List<ProductInfo> candidates, {
  double threshold = 0.45,
  int limit = 3,
}) {
  final t = normalizeProduct(target.name);
  final out = <MatchSuggestion>[];
  for (final c in candidates) {
    if (c.id == target.id) continue;
    if (c.storeIds.intersection(target.storeIds).isNotEmpty) continue;
    if (target.category != null && c.category != null && target.category != c.category) {
      continue;
    }
    final n = normalizeProduct(c.name);
    final bothSized = t.sizeValue != null && n.sizeValue != null;
    if (bothSized && !t.sameSize(n)) continue;
    final tCount = _count(target.name), cCount = _count(c.name);
    if (tCount != null && cCount != null && tCount != cCount) continue;
    final score = similarity(_core(t.name), _core(n.name)) + (bothSized ? 0.15 : 0);
    if (score >= threshold) out.add(MatchSuggestion(c, score));
  }
  out.sort((a, b) => b.score.compareTo(a.score));
  return out.take(limit).toList();
}

/// The name without tokens that carry no meaning across stores: store
/// brands and codes of one or two characters, bare numbers.
String _core(String name) => name
    .split(' ')
    .where((w) => w.length > 2 && !RegExp(r'^\d+$').hasMatch(w))
    .join(' ');

/// Pack count from "18PK", "12 CT", "6 PACK", which the normaliser leaves in
/// the name.
int? _count(String name) {
  final m = RegExp(r'(\d+)\s*(pk|ct|pack|count)\b', caseSensitive: false).firstMatch(name);
  return m == null ? null : int.parse(m.group(1)!);
}
