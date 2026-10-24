# Receipt scorecard

Every receipt reading we have, read the way the app reads it, against what the
paper receipt says. Regenerate with `UPDATE_SCORECARD=1 flutter test test/scorecard`.

**14 of 15 readings exact.**

| Receipt | How it was read | Lines read | Items come to | Printed | Result |
|---|---|---|---|---|---|
| Market Basket, Oct 22 | 3 photos, Android emulator | 64 of 64 | 361.33 | 361.33 | ✓ exact |
| Market Basket, Oct 22 | 3 photos given bottom first | 64 of 64 | 361.33 | 361.33 | ✓ exact |
| Market Basket, Oct 22 | 3 photos, phone turned 12° | 64 of 64 | 361.33 | 361.33 | ✓ exact |
| Market Basket, Oct 22 | 3 photos, phone tipped towards the top | 64 of 64 | 361.33 | 361.33 | ✓ exact |
| Market Basket, Oct 22 | 3 photos, receipt curling | 64 of 64 | 361.33 | 361.33 | ✓ exact |
| Market Basket, Oct 22 | 3 photos, turned, tipped and curling | 64 of 64 | 361.33 | 361.33 | ✓ exact |
| Market Basket, Oct 22 | iPhone, Text as read | 64 of 64 | 361.33 | 361.33 | ✓ exact (4 prices fixed by the check) |
| Market Basket, Oct 22 | 2 faded photos, not overlapping | 60 of 64 | 318.56 | 361.33 | ✗ off by 42.77, 4 lines missing |
| Market Basket, Oct 22 | top half, 1 photo | 33 of 64 | 169.86 | 361.33 | not checked: photos stop before the total |
| Market Basket, Oct 22 | top half, 3 photos | 33 of 64 | 169.86 | 361.33 | not checked: photos stop before the total |
| C&M Meats, Oct 24 | 1 photo, Android emulator | 3 of 3 | 5460.00 | 5460.00 | ✓ exact |
| C&M Meats, Oct 24 | Android phone, Text as read | 3 of 3 | 5460.00 | 5460.00 | ✓ exact |
| C&M Meats, Oct 24 | iPhone, Text as read | 3 of 3 | 5460.00 | 5460.00 | ✓ exact |
| FreshMart (typed example) | typed | 6 of 6 | 23.70 | 23.70 | ✓ exact |
| FreshMart (typed example) | as ML Kit spaces it | 6 of 6 | 23.70 | 23.70 | ✓ exact |
| Value Store (typed example) | typed | 2 of 2 | 9.71 | 9.71 | ✓ exact |
| Corner shop, day-first date (typed example) | typed | 3 of 3 | 6.45 | 6.45 | ✓ exact |
