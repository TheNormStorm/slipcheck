# Slipcheck — notes for Claude

Flutter app, Android first. Fully on-device: no network calls, no API keys, no accounts.
Do not add cloud OCR/LLM services without asking.

## Layout
- `lib/core/` — pure Dart, no Flutter imports. Parsing (`parsing/`) and product
  matching (`matching/`). All logic that can be unit-tested lives here.
- `lib/data/` — drift SQLite database (`database.dart`, generated `database.g.dart`)
  and `ReceiptRepository`.
- `lib/ocr/` — ML Kit adapter that turns an image into `OcrLine`s (text + bounding box).
- `lib/ui/` — screens. Kept minimal on purpose (testing UI).
- `test/fixtures/` — OCR output samples used by parser tests.

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
