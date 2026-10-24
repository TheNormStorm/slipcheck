import 'dart:io';

import 'package:intl/intl.dart' show NumberFormat;

/// The currency of the phone's region ("en_JM" → JMD), for a first receipt
/// that doesn't say; US dollars when the region is unknown.
String deviceCurrency() {
  try {
    final code = NumberFormat.simpleCurrency(locale: Platform.localeName.replaceAll('-', '_')).currencyName;
    return code == null || code.length != 3 ? 'USD' : code;
  } catch (_) {
    return 'USD';
  }
}
