# Slipcheck

Photograph a shopping receipt; Slipcheck reads it on the phone, lets you correct it,
and stores every purchase so you can track an item's price over time and across stores.

Everything stays on the device: OCR is Google ML Kit's bundled (offline) text
recogniser, parsing is plain Dart, storage is SQLite (drift). No accounts, no network.
Capture uses ML Kit's document scanner (crop, flatten, clean-up, several pages),
which Google Play services downloads once on first use; images never leave the phone.

Android first. The UI is deliberately bare while the parsing pipeline is proven.

## Run

```bash
flutter pub get
dart run build_runner build   # regenerates lib/data/database.g.dart after schema edits
flutter run                    # on a connected Android phone
flutter test
```

## How it works

photos (one or several, overlapping) → ML Kit text lines with positions → rows
(tilt corrected) → pages put in order and stitched on their overlap →
`ReceiptParser` → review screen (add/retake photos, correct anything) → saved →
per-product price history.

"MILK 2% 1L" and "Milk 2% 1 litre" are matched through a normalised product key
(`milk 2% 1000ml`); fuzzy matches are only suggested, and each confirmation is
remembered as an alias.
