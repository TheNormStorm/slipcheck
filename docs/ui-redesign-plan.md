# UI redesign plan

Source: `UI mockup with animations and loading states.zip` (design handoff:
README, 9 HTML prototypes, 34 screenshots, logo). Every screen comes in variant
**a** (soft, light) and **b** (punchy, dark) with the same layout and copy.

Goal: rebuild `lib/ui/` to the handoff without changing what the app does or
breaking its rules (on-device only, card section never shown or stored, money
in cents, parts of a comparison add up exactly).

## Decisions needed before building

| # | Decision | Recommendation |
|---|---|---|
| D1 | Which variant? | **a as the light theme, b as the dark theme**, following the phone setting. Drop b's offset "sticker" shadows if they feel loud. |
| D2 | Scanner screen (2a/2b) | **Keep Google's scanner.** It is a system screen and can't be restyled. A custom camera (CameraX) would lose its edge detection and clean-up. Use screen 2 as a short tips screen before it opens. |
| D3 | Save button disabled until the total matches (4a) | **Keep Save enabled.** Faded receipts can't always match, and they would become unsaveable. When it doesn't match, Save asks "Off by $X, save anyway?". |
| D4 | Fonts (Nunito, JetBrains Mono) | **Bundle them in the app** (open font licence, about 300 KB). Needs a one-time download of the font files from Google Fonts while building; your OK. |
| D5 | Receipts tab vs Home list | **Home**: scan card plus this month's receipts. **Receipts tab**: every receipt, By date / By store, plus search. No mockup exists for the tab; it reuses the Home list styling. |
| D6 | Share button on a receipt (7a) | **Share as text** (store, date, lines, total). No photo, so no card details. |
| D7 | Monthly spending chart | The Insights mockup dropped it. **Keep it** as a card under the price index. |

## Where the mockup conflicts with the app (resolved in the plan)

1. **Save disabled until the check passes** would block faded receipts → D3.
2. **Compare** lists four parts but drops "Bought more or less". Without it the
   parts no longer add up to the difference → keep all five bars.
3. **Reading log (3b)** prints `VISA ********4417`. The card section must never
   be shown → log lines and mini receipts show "·· card hidden ··" only.
4. **Categories**: the mockup has "Coffee" and files eggs under Pantry. The app
   has 13 categories (eggs are Dairy) → use the app's, each with its own icon.
5. **Friendly names** ("Milk 2% 1 gal", "Brown eggs 18pk"): the app shows
   receipt text. Plan: show names in sentence case automatically, keep
   "Also read as …" from the learned names, and rename for real fixes. Names
   like "MB LG BROWN CAGE FREE 18PK" stay that way until renamed.
6. **Contrast** (measured):
   - White on orange is **3.1:1**. That's fine for the large bold text, not
     for the 12–13px lines on the scan card and summary card. Those use
     `accDeep` (#C14A14, 4.9:1) or white pills.
   - Up/down text on the page background is about **4.1:1** at 12.5px.
     Darken it to ≥4.5:1 for small text.
7. **Whole Foods' chart colour vs the brand orange**: 1.03:1, indistinguishable.
   Orange in charts would read as "selected" or "brand". Leave orange out of
   the store colours; colours still follow the store.
8. **Present in the app, missing from the mockup.** Keep them, styled to the
   new tokens:
   - **Check it:** add, retake and remove photos; per-photo warnings (blurry,
     no overlap, no date); edit store, date and totals; Add item.
   - **Elsewhere:** merge stores (store ⋮), rename an item (name tap), undo a
     link (snackbar), manual entry review, the discard and restore dialogs,
     the store comparison detail.

## Architecture

- **Tokens and themes**:
  - `lib/ui/theme/`: a `SlipTokens` ThemeExtension (acc, accSoft, accDeep,
    up/down, surf2, line, radii, outline/shadow style) with light (a) and dark
    (b) instances.
  - `ChartPalette` keeps the validated store/chart colours (orange removed per
    point 7) and takes the ink colours from the tokens.
- **Motion**: `lib/ui/motion/`:
  - Durations and curves straight from the handoff table.
  - Widgets: `Rise` (staggered entrance), `PopIn`, `CountUp` (tabular
    figures), `Shimmer` skeletons, `ProgressRing`, `GrowBar`.
  - All check `MediaQuery.disableAnimations` and skip the pulse, shimmer and bob.
- **Components**: `lib/ui/components/`:
  - Building blocks: cards, pills/chips, stat tiles, segmented control, sheet
    scaffold, receipt row (with "vs usual" chip), store avatar, category icon
    tile, sparkline.
  - Branding: `SlipMascot` (CustomPainter: idle, blink, reading, sleepy) and
    `LogoMark` (CustomPainter, with the sweeping scan bar).
- **Shell**: `AppShell` with a 76px bottom bar (Home · Receipts · [Scan] ·
  Insights · Items), an `IndexedStack`, the raised scan button and the
  "Saved!" message host.
- **Real reading progress** (new, in `lib/ocr/receipt_reader.dart`):
  - A `ReadProgress` stream: per-photo OCR, rows straightened, photos joined
    (rows cut), items found, card hidden, items matched, total check, plus
    log lines. The log is redacted the same way as stored text.
  - Percent is computed from finished steps, never from timers.
  - "Finding edges" only appears for scanner photos; the scanner did that work.
- **Small new computations**, pure Dart and tested:
  - Prices up/down per receipt, for "↑ 3 prices", "3 went up / 1 went down"
    and "vs usual +1.12".
  - Insights date ranges (3 months / this month / all).
  - Items search and filters (went up, category).
  - Sparkline data.
  - Sentence-case names.
- **App icon and splash**:
  - The logo as an Android adaptive icon: orange background layer, receipt
    and bar as a vector foreground drawn from the SVG.
  - Android 12 splash using the same mark. No raster exports needed.
- **Onboarding flag**: a one-row `settings` table (schema v5) holds
  `onboardingSeen`. No new package.

## Phases

Each phase ends with:
- `flutter analyze` clean and `flutter test` green;
- screenshots on the emulator in light and dark, compared side by side with
  the mockup's;
- a release build checked on the emulator.

| Phase | Scope | Depends on | Size |
|---|---|---|---|
| **0. Decisions** | D1–D7 above | — | — |
| **1. Foundation** | Tokens and two themes, fonts, Material Symbols, logo, app icon, splash, mascot, motion widgets, components, bottom-bar shell | 0 | L |
| **2. Core flow** | Home (count-up, skeletons, staggered list, "↑ N prices" chip, Saved message); Empty home; Onboarding; Scanner tips; **Reading screen with real progress**; **Check it** (summary card, rows resolving one by one, Link nudge, photos sheet, warnings, sticky Save); Edit item sheet; **Saved celebration** | 1 | L |
| **3. Browse** | Receipts tab (By date / By store, search); Receipt detail (tiles, vs-usual chips, share as text); Compare (centre-out bars, all five parts); Store page (coloured header, overlapping tiles, pick 2) | 1 (2 for the Saved hook) | M |
| **4. Insights and Items** | Insights (ranges, index columns, price moves, category bar, monthly chart, Slip's tip); Items (search, filter chips, category icons, sparklines); Price history (bars per visit, store tiles, link card, "also read as", rename) | 1 | M |
| **5. Menu and dialogs** | Popover menu with "Everything stays on this phone."; restyled Clear all, Already saved, Discard, Restore dialogs; haptics | 1 | S |
| **6. Polish** | Reduced motion pass; contrast check of every text/background pair; frame timing in profile mode on a low-end emulator; TalkBack labels for animated figures; final screenshot comparison | 2–5 | M |

Phases 3, 4 and 5 can run in parallel once phase 1 is in. Phase 2 is the
most visible and the riskiest, so it goes first.

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Animation-heavy screens stutter on cheaper phones | Medium | Use implicit animations and `RepaintBoundary` around shimmer and charts; profile on a low-end emulator in phase 6; reduced motion turns the heavy parts off. |
| Reading progress looks jumpy, because ML Kit reads a whole photo in one call with no partial progress | High | Each photo's OCR is one step, with the spinner running; the counts that appear between steps carry the "a lot is happening" feel. |
| Delight hides bad reads (celebrating a receipt that's off by $40) | Medium | The celebration says so when the total didn't match ("Saved. 1 line may be off"); the Check it warnings stay prominent. |
| Font download not allowed | Low | Use Roboto, the system font, until it is; the layout doesn't depend on Nunito's metrics. |
| Widget tests break on the new screens | High (expected) | Rewrite the UI tests per phase; the 100+ logic tests are unaffected. |
| A large one-shot rewrite drifts from the mockup | Medium | Phase by phase, each with side-by-side screenshots against the handoff PNGs. |

## Not changing

Parsing, stitching, matching, analytics maths, the database (apart from the
small settings table), privacy rules and file handling. The redesign is
presentation plus the new progress stream and a few small derived numbers.
