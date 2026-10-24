# Slipcheck — notes for Claude

Flutter app, Android first. Fully on-device: no network calls, no API keys, no accounts.
Do not add cloud OCR/LLM services without asking.

## Layout
- `lib/core/` — pure Dart, no Flutter imports. Parsing (`parsing/`: row grouping,
  multi-photo stitching, page quality, receipt parser) and product matching
  (`matching/`). All logic that can be unit-tested lives here.
- `lib/core/analytics/` — receipt diff, personal price index, price changes,
  store comparison. Price comparisons are like-for-like (same store and unit);
  the receipt diff's parts must always sum to the difference (tested).
- `lib/data/` — drift SQLite database (`database.dart`, generated `database.g.dart`)
  and `ReceiptRepository`.
- `lib/ocr/` — ML Kit adapter that turns an image into `OcrLine`s (text + bounding box).
  `read_pipeline.dart` runs the reading steps and reports real progress to the
  Reading screen; its log must only show redacted rows (tested).
- `lib/ui/` — screens, redesigned from the handoff in docs/ui-redesign-plan.md
  (tokens in `theme/`, motion widgets honour reduced motion). `scan_flow.dart`
  wraps the document scanner and the photos behind a receipt under review.
  Scan flow: tips (first time) → scanner → Reading → Check it → Saved.
- `test/fixtures/` — OCR output samples used by parser tests. `*.json` files are
  real ML Kit output (redact names). The app writes the same JSON per photo to
  `Android/data/com.slipcheck.slipcheck/files/ocr/` — that is how new fixtures
  are made from receipts that read badly.

## Privacy rules
- Never store the card section: run OCR rows through `withoutPaymentSection`
  and OCR lines through `withoutPaymentLines` (lib/core/parsing/redaction.dart)
  before persisting. Receipt files live only where `ReceiptFiles` says, so
  delete and clear-all can remove every copy.

## Conventions
- Money is integer cents (`int`) everywhere; never `double` for money.
- The code is hand-formatted (~110 columns). Don't run `dart format`.
- Quantities may be fractional (weighed items), stored as `double`.
- Product sizes are normalised to ml / g / each.
- Fuzzy product matches are suggestions; only user confirmation creates an alias.
- After changing tables in `database.dart`: `dart run build_runner build`, bump
  `schemaVersion`, add a migration step.

## Commands
- `flutter test` — must pass before committing.
- `flutter analyze` — keep clean.
- Text contrast is tested (test/ui/contrast_test.dart): add any new text /
  background pair there.
