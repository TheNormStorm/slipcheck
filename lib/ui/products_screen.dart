import 'package:flutter/material.dart';

import '../core/money.dart';
import '../data/receipt_repository.dart';
import 'price_history_screen.dart';

/// Testing UI: every known product, tap one for its price history.
class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key, required this.repo});

  final ReceiptRepository repo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Items')),
      body: FutureBuilder(
        future: repo.products(),
        builder: (context, snap) {
          final products = snap.data ?? const [];
          if (products.isEmpty) return const Center(child: Text('No items yet.'));
          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, i) {
              final p = products[i];
              return ListTile(
                title: Text(p.displayName),
                subtitle: Text('Bought ${p.purchaseCount}×'),
                trailing: Text(p.lastUnitPriceCents == null
                    ? ''
                    : formatCents(p.lastUnitPriceCents!)),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PriceHistoryScreen(repo: repo, product: p),
                )),
              );
            },
          );
        },
      ),
    );
  }
}
