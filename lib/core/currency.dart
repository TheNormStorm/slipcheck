/// Which currency a receipt is in, and showing amounts in it. A receipt
/// rarely names its currency ("$" is used by a dozen), so it is worked out
/// from clues: codes and symbols ("JMD", "J$", "€"), tax names ("GCT",
/// "HST", "VAT"), and where the shop is (a US state and ZIP code, a
/// Jamaican parish). Unsure means null; the app then uses the store's last
/// currency, then the one you use most.
library;

/// Currencies the app knows a symbol for, in the order the picker lists them.
const knownCurrencies = <String, String>{
  'USD': r'$',
  'JMD': r'J$',
  'CAD': r'C$',
  'GBP': '£',
  'EUR': '€',
  'TTD': r'TT$',
  'BBD': r'Bds$',
  'XCD': r'EC$',
  'KYD': r'CI$',
  'BSD': r'B$',
};

String currencySymbol(String code) => knownCurrencies[code] ?? '$code ';

const _states = 'AL|AK|AZ|AR|CA|CO|CT|DE|DC|FL|GA|HI|ID|IL|IN|IA|KS|KY|LA|ME|MD|MA|MI|MN|MS|MO|MT|NE|NV|NH|NJ|NM|NY|'
    'NC|ND|OH|OK|OR|PA|RI|SC|SD|TN|TX|UT|VT|VA|WA|WV|WI|WY';
const _provinces = 'AB|BC|MB|NB|NL|NS|NT|NU|ON|PE|QC|SK|YT';

final _clues = <(RegExp, String, int)>[
  // Written out.
  (RegExp(r'\bUSD\b|\bUS\$'), 'USD', 5),
  (RegExp(r'\bJMD\b|\bJA?\$'), 'JMD', 5),
  (RegExp(r'\bCAD\b|\bCA?\$'), 'CAD', 5),
  (RegExp(r'\bGBP\b|£'), 'GBP', 5),
  (RegExp(r'\bEUR\b|€'), 'EUR', 5),
  (RegExp(r'\bTTD\b|\bTT\$'), 'TTD', 5),
  (RegExp(r'\bBBD\b|\bBDS\$', caseSensitive: false), 'BBD', 5),
  (RegExp(r'\bXCD\b|\bEC\$'), 'XCD', 5),
  (RegExp(r'\bKYD\b|\bCI\$'), 'KYD', 5),
  (RegExp(r'\bBSD\b'), 'BSD', 5),
  // Jamaica: General Consumption Tax, Taxpayer Registration Number, the
  // country, its 876 area code, parishes and towns.
  (RegExp(r'\bG\.?C\.?T\b'), 'JMD', 3),
  (RegExp(r'\bTRN\b'), 'JMD', 3),
  (RegExp(r'\bJAMAICA\b|\bJA\.?\s*W\.?\s*I\b', caseSensitive: false), 'JMD', 4),
  (RegExp(r'\(?\b876\)?[\s.-]?\d{3}[\s.-]?\d{4}\b'), 'JMD', 2),
  (
    RegExp(
        r'\b(CLARENDON|ST\.?\s*CATHERINE|ST\.?\s*ANDREW|ST\.?\s*ELIZABETH|WESTMORELAND|TRELAWNY|ST\.?\s*JAMES|HANOVER|'
        r'ST\.?\s*ANN|ST\.?\s*MARY|MAY\s*PEN|SPANISH\s*TOWN|MONTEGO\s*BAY|MANDEVILLE|OCHO\s*RIOS|PORTMORE|'
        r'HALF\s*WAY\s*TREE|SAVANNA-?LA-?MAR|LINSTEAD|OLD\s*HARBOUR|NEGRIL|MORANT\s*BAY|PORT\s*ANTONIO|'
        r'BLACK\s*RIVER|SANTA\s*CRUZ|CHRISTIANA)\b',
        caseSensitive: false),
    'JMD',
    3,
  ),
  // United States: state and ZIP code, or a state's sales tax line.
  (RegExp('\\b($_states)\\s+\\d{5}(?:-\\d{4})?\\b'), 'USD', 3),
  // ("MA 6.25% Sal es Tax": OCR may split the words.)
  (RegExp('\\b($_states)\\s+\\d{1,2}(?:\\.\\d{1,3})?\\s*%[^\\n]{0,12}\\btax\\b', caseSensitive: false), 'USD', 3),
  // Canada: province and postal code, or GST/HST/PST/QST.
  (RegExp('\\b($_provinces)\\s+[A-Z]\\d[A-Z]\\s?\\d[A-Z]\\d\\b'), 'CAD', 3),
  (RegExp(r'\b(HST|QST)\b'), 'CAD', 3),
  (RegExp(r'\b(GST|PST)\b'), 'CAD', 2),
  // United Kingdom and Europe.
  (RegExp(r'\b[A-Z]{1,2}\d[A-Z\d]?\s+\d[A-Z]{2}\b'), 'GBP', 2),
  (RegExp(r'\b(MWST|UST|IVA|TVA|BTW)\b', caseSensitive: false), 'EUR', 2),
];

/// How strongly the rows point at each currency.
Map<String, int> currencyClues(Iterable<String> rows) {
  final text = rows.join('\n');
  final score = <String, int>{};
  for (final (pattern, code, weight) in _clues) {
    if (pattern.hasMatch(text)) score[code] = (score[code] ?? 0) + weight;
  }
  return score;
}

/// The receipt's currency from its rows, or null when the clues are weak
/// or point two ways.
String? detectCurrency(Iterable<String> rows) {
  final score = currencyClues(rows);
  if (score.isEmpty) return null;
  final ranked = score.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final best = ranked.first;
  final runnerUp = ranked.length > 1 ? ranked[1].value : 0;
  return best.value >= 3 && best.value - runnerUp >= 2 ? best.key : null;
}

/// "5,460.00": an amount with thousands grouped, for showing.
String groupedAmount(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  final whole = (abs ~/ 100).toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');
  return '$sign$whole.${(abs % 100).toString().padLeft(2, '0')}';
}

/// An amount for showing: grouped, with the currency's symbol when it is
/// not the one most of your receipts are in ([main]), so the usual case
/// stays uncluttered: "5,460.00" or "J$5,460.00".
String formatMoney(int cents, String currency, {String? main}) {
  final amount = groupedAmount(cents.abs());
  final sign = cents < 0 ? '-' : '';
  return currency == main ? '$sign$amount' : '$sign${currencySymbol(currency)}$amount';
}
