import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/receipt_repository.dart';

/// Reloads a screen's data whenever the repository changes (coalescing the
/// burst of table updates a single save makes).
mixin ReloadOnChange<T extends StatefulWidget> on State<T> {
  ReceiptRepository get repo;
  StreamSubscription<void>? _changes;
  Timer? _debounce;

  /// Re-runs the screen's queries; called inside setState.
  void reload();

  @override
  void initState() {
    super.initState();
    _changes = repo.changes.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 80), () {
        if (mounted) setState(() => reload());
      });
    });
  }

  @override
  void dispose() {
    _changes?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
}
