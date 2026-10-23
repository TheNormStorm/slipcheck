# Slipcheck — notes for Claude

Flutter app, Android first. Fully on-device: no network calls, no API keys, no accounts.
Do not add cloud OCR/LLM services without asking.

## Layout
- `lib/core/` — pure Dart, no Flutter imports. Parsing (`parsing/`: row grouping,
  multi-photo stitching, page quality, receipt parser) and product matching
  (`matching/`). All logic that can be unit-tested lives here.
- `lib/data/` — drift SQLite database (`database.dart`, generated `database.g.dart`)
  and `ReceiptRepository`.
- `lib/ocr/` — ML Kit adapter that turns an image into `OcrLine`s (text + bounding box).
- `lib/ui/` — screens. Kept minimal on purpose (testing UI). `scan_flow.dart`
  wraps the document scanner and the photos behind a receipt under review.
- `test/fixtures/` — OCR output samples used by parser tests. `*.json` files are
  real ML Kit output (redact names). The app writes the same JSON per photo to
  `Android/data/com.slipcheck.slipcheck/files/ocr/` — that is how new fixtures
  are made from receipts that read badly.

## Conventions
- Money is integer cents (`int`) everywhere; never `double` for money.
- Quantities may be fractional (weighed items), stored as `double`.
- Product sizes are normalised to ml / g / each.
- Fuzzy product matches are suggestions; only user confirmation creates an alias.
- After changing tables in `database.dart`: `dart run build_runner build`, bump
  `schemaVersion`, add a migration step.

## Commands
- `flutter test` — must pass before committing.
- `flutter analyze` — keep clean.
