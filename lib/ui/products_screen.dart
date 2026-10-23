import 'package:flutter/material.dart';

import '../core/categories.dart';
import '../core/money.dart';
import '../data/receipt_repository.dart';
import 'price_history_screen.dart';

/// Every item you have bought, grouped by category, most spent first.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, required this.repo});

  final ReceiptRepository repo;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late Future<List<ProductSummary>> _products = widget.repo.products();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Items')),
      body: FutureBuilder(
        future: _products,
        builder: (context, snap) {
          final products = snap.data ?? const [];
          if (products.isEmpty) return const Center(child: Text('No items yet.'));
          final groups = <Category, List<ProductSummary>>{};
          for (final p in products) {
            groups.putIfAbsent(p.category, () => []).add(p);
          }
          final categories = Category.values.where(groups.containsKey);
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              for (final c in categories) ...[
                Container(
                  color: theme.colorScheme.surfaceContainerHigh,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    Expanded(child: Text(c.label, style: theme.textTheme.titleSmall)),
                    Text('${groups[c]!.length} item${groups[c]!.length == 1 ? '' : 's'} · '
                        '\$${formatCents(groups[c]!.fold(0, (s, p) => s + p.spentCents))}',
                        style: theme.textTheme.bodySmall),
                  ]),
                ),
                for (final p in groups[c]!..sort((a, b) => b.spentCents.compareTo(a.spentCents)))
                  ListTile(
                    title: Text(p.displayName),
                    subtitle: Text('Bought ${p.purchaseCount}×'
                        '${p.storeIds.length > 1 ? ' at ${p.storeIds.length} stores' : ''}'),
                    trailing: Text(p.lastUnitPriceCents == null
                        ? ''
                        : p.lastUnit == 'each'
                            ? '${formatCents(p.lastUnitPriceCents!)} each'
                            : '${formatCents(p.lastUnitPriceCents!)}/${p.lastUnit}'),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PriceHistoryScreen(repo: widget.repo, product: p),
                      ));
                      setState(() {
                        _products = widget.repo.products();
                      });
                    },
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
