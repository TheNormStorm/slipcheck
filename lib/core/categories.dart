/// Item categories, in the order they are listed.
enum Category {
  produce('Produce'),
  meat('Meat & seafood'),
  dairy('Dairy & eggs'),
  bakery('Bakery'),
  frozen('Frozen'),
  pantry('Pantry'),
  snacks('Snacks'),
  drinks('Drinks'),
  household('Household'),
  personalCare('Personal care'),
  pet('Pet'),
  deposits('Deposits & fees'),
  other('Other');

  const Category(this.label);
  final String label;

  static Category? byName(String? name) =>
      Category.values.where((c) => c.name == name).firstOrNull;
}

/// Words that make up department headings printed on receipts ("PRODUCE
/// DEPT", "FRESH POULTRY", "TAX GROCERY"). Deliberately excludes words that
/// also end wrapped item names ("CHICKEN", "STEAK", "BREAD"), so a second
/// name line is never mistaken for a heading.
const _headingWords = {
  'grocery', 'groceries', 'produce', 'dept', 'department', 'dairy', 'meat', 'meats',
  'seafood', 'deli', 'bakery', 'frozen', 'ice', 'cream', 'haba', 'hbc', 'health',
  'beauty', 'household', 'pet', 'pets', 'beer', 'wine', 'bottle', 'deposit',
  'prepackages', 'prepackaged', 'specialty', 'foods', 'food', 'dry', 'goods', 'fresh',
  'poultry', 'store', 'cut', 'beef', 'organic', 'fruit', 'fruits', 'vegetables',
  'yogurt', 'cheese', 'eggs', 'french', 'fries', 'tax', 'taxable', 'general',
  'merchandise', 'snacks', 'beverages', 'pharmacy', 'floral', 'bulk', 'natural',
  'cereal', 'candy', 'baby', 'paper', 'cleaning', 'and', '&',
};

/// Whether a name-only receipt row is a department heading.
bool isDepartmentHeading(String row) {
  final words = row.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty || words.length > 4) return false;
  return words.every(_headingWords.contains);
}

/// Headings that say what is under them. Others ("GROCERY", "SPECIALTY
/// FOODS") are too broad and only used when no keyword matches.
const _specificHeadings = <String, Category>{
  'produce': Category.produce, 'fruit': Category.produce, 'vegetables': Category.produce,
  'poultry': Category.meat, 'beef': Category.meat, 'meat': Category.meat,
  'meats': Category.meat, 'seafood': Category.meat,
  'dairy': Category.dairy, 'cheese': Category.dairy, 'eggs': Category.dairy,
  'yogurt': Category.dairy,
  'bakery': Category.bakery,
  'frozen': Category.frozen, 'ice': Category.frozen, 'fries': Category.frozen,
  'haba': Category.personalCare, 'hbc': Category.personalCare,
  'beauty': Category.personalCare, 'pharmacy': Category.personalCare,
  'household': Category.household, 'cleaning': Category.household,
  'paper': Category.household,
  'pet': Category.pet, 'pets': Category.pet,
  'deposit': Category.deposits,
  'beer': Category.drinks, 'wine': Category.drinks, 'beverages': Category.drinks,
  'snacks': Category.snacks, 'candy': Category.snacks,
};

const _broadHeadings = <String, Category>{
  'grocery': Category.pantry, 'dry': Category.pantry, 'specialty': Category.pantry,
  'cereal': Category.pantry, 'bulk': Category.pantry,
};

/// Keyword rules, checked in order (first match wins), against the
/// lowercased name. More specific phrases come before the words they contain
/// ("coconut milk" before "milk", "green bean" before "bean").
const _keywords = <(String, Category)>[
  ('deposit', Category.deposits), ('bag fee', Category.deposits),
  ('single roll', Category.household), ('paper towel', Category.household),
  ('watermelon', Category.produce), ('juice', Category.drinks),
  ('cocnut', Category.pantry), ('coconut', Category.pantry),
  ('green bean', Category.produce), ('ice cream', Category.frozen),
  ('frozen', Category.frozen), ('frzn', Category.frozen), ('fries', Category.frozen),
  ('cat ', Category.pet), ('dog ', Category.pet), ('chow', Category.pet),
  ('litter', Category.pet),
  ('milk', Category.dairy), ('cheese', Category.dairy), ('cheddar', Category.dairy),
  ('mozz', Category.dairy), ('yogurt', Category.dairy), ('butter', Category.dairy),
  ('egg', Category.dairy), ('cream', Category.dairy),
  ('chicken', Category.meat), ('beef', Category.meat), ('gr bf', Category.meat), ('steak', Category.meat),
  ('ribeye', Category.meat), ('pork', Category.meat), ('turkey', Category.meat),
  ('salmon', Category.meat), ('shrimp', Category.meat), ('drumstick', Category.meat),
  ('sausage', Category.meat), ('bacon', Category.meat), ('ham ', Category.meat),
  ('banana', Category.produce), ('apple', Category.produce), ('pear', Category.produce),
  ('grape', Category.produce), ('kiwi', Category.produce), ('berr', Category.produce),
  ('onion', Category.produce), ('pepper', Category.produce), ('carrot', Category.produce),
  ('broccoli', Category.produce), ('cabbage', Category.produce), ('yam', Category.produce),
  ('potato', Category.produce), ('lettuce', Category.produce), ('tomato', Category.produce),
  ('plantain', Category.produce), ('okra', Category.produce), ('scallion', Category.produce),
  ('lemon', Category.produce), ('lime', Category.produce), ('avocado', Category.produce),
  ('dragon fruit', Category.produce), ('rosemary', Category.produce),
  ('cilantro', Category.produce), ('garlic', Category.produce),
  ('bread', Category.bakery), ('pita', Category.bakery), ('bagel', Category.bakery),
  ('bun', Category.bakery), ('roll ', Category.bakery), ('tortilla', Category.bakery),
  ('sourdough', Category.bakery),
  ('chip', Category.snacks), ('cracker', Category.snacks), ('popcorn', Category.snacks),
  ('cookie', Category.snacks), ('candy', Category.snacks), ('chocolate', Category.snacks),
  ('soda', Category.drinks), ('cola', Category.drinks), ('coke', Category.drinks),
  ('pepsi', Category.drinks), ('water', Category.drinks), ('spring', Category.drinks),
  ('juice', Category.drinks), ('cran', Category.drinks), ('sparkling', Category.drinks),
  ('coffee', Category.drinks), ('tea', Category.drinks), ('caffeine', Category.drinks),
  ('foil', Category.household), ('paper', Category.household), ('towel', Category.household),
  ('trash', Category.household), ('wste', Category.household), ('waste', Category.household),
  ('bskt bg', Category.household),
  ('dawn', Category.household), ('comet', Category.household), ('detergent', Category.household),
  ('tissue', Category.household),
  ('crest', Category.personalCare), ('toothpaste', Category.personalCare),
  ('shampoo', Category.personalCare), ('deodorant', Category.personalCare),
  ('rice', Category.pantry), ('oil', Category.pantry), ('bean', Category.pantry),
  ('pasta', Category.pantry), ('sauce', Category.pantry), (' sce', Category.pantry),
  ('flour', Category.pantry), ('sugar', Category.pantry), ('salt', Category.pantry),
  ('cereal', Category.pantry), ('soup', Category.pantry),
];

/// Best guess at an item's category: a keyword in its name, else the
/// department heading it was printed under, else Other.
Category categorize(String name, {String? section}) {
  final text = ' ${name.toLowerCase()} ';
  final words = (section ?? '').toLowerCase().split(RegExp(r'\s+'));
  for (final (keyword, category) in _keywords) {
    if (text.contains(keyword)) return category;
  }
  for (final w in words) {
    final c = _specificHeadings[w];
    if (c != null) return c;
  }
  for (final w in words) {
    final c = _broadHeadings[w];
    if (c != null) return c;
  }
  return Category.other;
}
