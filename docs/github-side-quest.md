# Side quest: GitHub, by doing it

You'll put Slipcheck on GitHub, merge three changes through pull requests,
publish a release, and then watch the app on your phone find its own
update. Each quest says what to type, what it does, and how to check it
worked. Run the commands in the Terminal panel, from the project folder
(`/Users/mike/Projects/Slipcheck`).

You're already signed in to the GitHub command line tool (`gh`) as
**TheNormStorm**, so nothing below asks for a password.

---

## The picture in your head

Think of the project as a notebook with a time machine.

| Word | What it is | In Slipcheck right now |
|---|---|---|
| **Repository (repo)** | The project folder plus its full history. | `/Users/mike/Projects/Slipcheck` |
| **Commit** | A saved snapshot of the files, with a message saying why. Saved on *your* computer only. | 34 so far on `main` (`git log --oneline` lists them) |
| **Branch** | A separate line of commits, so a change can be worked on without touching the main line. | `main`, plus `fix-big-amounts`, `update-check`, `mismatch-help` |
| **Remote** | A copy of the repo somewhere else. Usually called `origin`. | None yet: Quest 1 makes one on GitHub |
| **Push** | Send your new commits *to* the remote. | |
| **Pull** | Fetch new commits *from* the remote and add them to your copy. | |
| **Pull request (PR)** | On GitHub: "here's a branch, please merge it into main". A page showing exactly what changes, where you read it before saying yes. | |
| **Merge** | Bring a branch's commits into another branch (usually main). | |
| **Tag** | A permanent name stuck on one commit, like `v0.10.0`. | |
| **Release** | A tag on GitHub with files attached (the APK) and notes. What the app's "Check for updates" reads. | |

The flow, every time:

```
branch → commits → push → pull request → review → merge → pull → (release)
```

**Commit** is "save". **Push** is "upload". **Pull** is "download". A **PR**
is "ask before it goes into main". Even working alone, a PR is worth it:
you see the whole change in one place, you can come back to why it was
made, and later GitHub can run the tests on it automatically.

**When to make a PR:** for every change that goes into main. Small fix,
big feature, doesn't matter: branch, PR, merge. Main should always be
something you'd be happy to build and install.

**Useful anytime:**

```bash
git status
```
What's changed and not committed yet, and which branch you're on.

```bash
git log --oneline --graph --all
```
Every commit on every branch, as a tree.

---

## Quest 1: Put the project on GitHub

**Goal:** a public repo at github.com/TheNormStorm/slipcheck holding `main`.

1. Make sure you're on main with nothing half-done:
   ```bash
   git switch main
   ```
   ```bash
   git status
   ```
   You should see `On branch main` and nothing to commit (the mockup zip
   shows as untracked: that's fine, it's never been committed and won't
   be).

2. Create the repo on GitHub and connect it as `origin`:
   ```bash
   gh repo create TheNormStorm/slipcheck --public --source . --remote origin --description "Photograph receipts, track prices. Everything stays on your phone."
   ```
   This makes an empty repo on GitHub and remembers its address under the
   name `origin`. Nothing is uploaded yet.

3. Push main:
   ```bash
   git push -u origin main
   ```
   `push` uploads your commits. `-u` ("upstream") remembers that your
   `main` goes with `origin/main`, so next time `git push` and `git pull`
   need no extra words.

**Check:** open https://github.com/TheNormStorm/slipcheck. You'll see the
files, the README, and "34 commits" (or so). Click **commits**: it's the
same list as `git log --oneline`.

> What's public now: the code, the tests (their receipt samples have names
> and card details removed) and the commit history, credited to "Michael
> Gayle". Your receipts and photos are never in the repo: they live only in
> the app on your phone.

---

## Quest 2: Your first pull request

**Goal:** merge `fix-big-amounts` (the fix for your C&M Meats receipt:
"$2,850.00" was read as 850.00) through a PR.

1. Look at the branch before you send it:
   ```bash
   git log --oneline main..fix-big-amounts
   ```
   Commits on the branch that main doesn't have (one).
   ```bash
   git diff main fix-big-amounts --stat
   ```
   Which files it changes.

2. Push the branch:
   ```bash
   git push -u origin fix-big-amounts
   ```

3. Open the pull request:
   ```bash
   gh pr create --base main --head fix-big-amounts --fill
   ```
   `--fill` uses the commit message as the PR's title and description. It
   prints the PR's address.

4. Review it on GitHub. Open the address, then:
   - **Conversation:** the description.
   - **Commits:** what's in it.
   - **Files changed:** every line added (green) and removed (red). This is
     the review. Look at `test/fixtures/cm_meats_phone.txt`: it's your
     receipt as text, with the cashier's name replaced.

5. Merge it: press **Merge pull request**, then **Confirm merge**, then
   **Delete branch** (the branch on GitHub; its commits are now in main).

6. Bring the merge back to your computer. GitHub's main now has a commit
   yours doesn't:
   ```bash
   git switch main
   ```
   ```bash
   git pull
   ```
   That's **pull**: download what's new on `origin/main` and add it to
   your `main`.

**Check:** `git log --oneline -3` shows "Merge pull request #1…" at the
top.

---

## Quest 3: Two more, on your own

Same steps, for the other two branches. Try it without looking back up.

- `update-check`: the "Check for updates" button (the app's only network
  call, and only when you tap it).
- `mismatch-help`: when a receipt doesn't add up, Check it suggests the
  likely fix ("may be 2850.00, not 850.00"), and "Send reading details"
  shares what the OCR read.
- `scorecard`: the receipt scorecard. It's built on top of
  `fix-big-amounts`, so merge that one first; then this PR only shows the
  scorecard's own commit. (A branch built on another branch is called
  *stacked*.)

Hints:
```bash
git push -u origin update-check
```
```bash
gh pr create --base main --head update-check --fill
```

Merge on GitHub, then `git switch main` and `git pull`. Repeat for
`mismatch-help`.

**What if GitHub says "This branch has conflicts"?** Both branches
changed the same lines differently, so Git can't choose. These three
don't overlap, so it shouldn't happen here. If it ever does, ask Claude:
"resolve the conflicts on <branch>".

**Check:** `git log --oneline --graph -12` shows four merges on main.
Then delete your local copies of the merged branches:
```bash
git branch -d fix-big-amounts update-check mismatch-help scorecard
```
`-d` refuses to delete a branch that isn't merged, so this is safe.

---

## Quest 4: Your first release

**Goal:** version 0.10.0 on GitHub, with the APK, installed on your phone
from there.

1. On an up-to-date main:
   ```bash
   git switch main
   ```
   ```bash
   git pull
   ```

2. Build the APK. The version comes from `pubspec.yaml` (`0.10.0+10`):
   ```bash
   flutter build apk --release --split-per-abi --target-platform android-arm64
   ```
   ```bash
   cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk build/slipcheck-0.10.0-arm64-v8a.apk
   ```

3. Tag the commit and publish the release with the APK attached:
   ```bash
   gh release create v0.10.0 build/slipcheck-0.10.0-arm64-v8a.apk --title "Slipcheck 0.10.0" --notes "Reads amounts like 2,850.00. Suggests fixes when a receipt doesn't add up. Check for updates in the menu."
   ```
   This creates the tag `v0.10.0` on GitHub's main, makes the release
   page, and uploads the APK. The notes are what the app shows when it
   finds the update.

4. Pull the new tag down:
   ```bash
   git pull --tags
   ```

**Check:** https://github.com/TheNormStorm/slipcheck/releases shows
0.10.0 with the APK under **Assets**. On your phone, open that page,
download the APK and install it over the old app. Your receipts stay.

---

## Quest 5: Ship an update and let the app find it

**Goal:** the full loop. A change goes through a PR, gets released, and
the app on your phone offers it.

1. Make a branch:
   ```bash
   git switch -c bump-0.10.1
   ```

2. In `pubspec.yaml`, change `version: 0.10.0+10` to `version: 0.10.1+11`.
   Both numbers go up: the first is the version people see, and the
   second is a counter Android checks. If it doesn't go up, the phone
   refuses the update.

3. Commit it. `add` picks what goes in the snapshot; `commit` saves it:
   ```bash
   git add pubspec.yaml
   ```
   ```bash
   git commit -m "Version 0.10.1"
   ```

4. Push, PR, merge, pull (Quest 2), then release (Quest 4 steps 2–4,
   with `0.10.1` instead of `0.10.0`).

5. On your phone, still on 0.10.0: **⋯ → Check for updates**. It says
   "Slipcheck 0.10.1 is out" with your notes. Tap **Download**, then open
   the file to install.

That's the update path working end to end.

---

## Good habits

- **`git status` before every commit.** Know what you're saving.
- **One branch per change.** Name it after what it does: `fix-…`, `add-…`.
- **Small PRs.** Easier to read, and easier to undo.
- **Never commit secrets:** passwords, API keys, signing keys. Once
  pushed to a public repo, assume it's copied.
- **Don't `git push --force` to main.** It rewrites history that's already
  public.
- **Releases come from main**, after `git pull`.
- **Build releases on this Mac.** Each APK is signed with a key that lives
  on this computer, and Android only installs an update signed with the
  same key as the app already on the phone. Moving to a proper release
  key (needed if you ever build elsewhere, or let GitHub build for you) is
  a later quest.

## Cheat sheet

```bash
git switch -c my-branch
```
New branch from where you are, and switch to it.

```bash
git add path/to/file
```
Choose what goes in the next commit.

```bash
git commit -m "Why this change"
```
Save the snapshot locally.

```bash
git push -u origin my-branch
```
Upload the branch (first time; afterwards just `git push`).

```bash
gh pr create --fill
```
Open a pull request for the current branch.

```bash
git pull
```
Download and merge what's new on GitHub.

```bash
git switch main
```
Go back to main.

## Next quests, when you're ready

- **GitHub Actions:** run `flutter test` on every PR automatically, so a
  red ✗ shows up before you merge.
- **A release signing key:** stored safely, so GitHub can build and sign
  the APK for you when you push a tag.
- **Issues:** a to-do list on GitHub. A PR that says "Fixes #3" closes
  issue 3 when it merges.
