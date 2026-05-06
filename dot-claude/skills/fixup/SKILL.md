---
name: fixup
description: Create `git commit --fixup` commits for the current working-tree changes, routing each hunk to the commit that originally introduced the lines it touches. Use when the user says "fixup", "create fixup commits", "fixup these changes", or otherwise asks to attribute pending changes back to their originating commits for a later `git rebase --autosquash`.
---

# Fixup

Take the current uncommitted changes (staged + unstaged) and turn them into one
or more `git commit --fixup=<sha>` commits, where each fixup targets the commit
that originally introduced the line(s) being modified. The result is a series
of fixup commits ready for `git rebase -i --autosquash <base>`.

## Step 1 — sanity check the repo state

Run these in parallel:

```sh
git status --porcelain
git rev-parse --abbrev-ref HEAD
git log --oneline @{upstream}..HEAD 2>/dev/null || git log --oneline $(git merge-base HEAD origin/HEAD 2>/dev/null || git merge-base HEAD main 2>/dev/null || git merge-base HEAD master)..HEAD
```

Bail out early and ask the user if any of these are true:

- Working tree is clean — nothing to fixup.
- Currently in the middle of a rebase, merge, cherry-pick, or bisect (`git
    status` will say so). Don't create commits during another in-progress
    operation.
- HEAD is detached. Confirm the user really wants fixup commits on a detached
    HEAD before proceeding.

Identify the **fixup base** — the oldest commit it's reasonable to target:

1. If the branch tracks an upstream, use `git merge-base HEAD @{upstream}`.
2. Otherwise try `git merge-base HEAD origin/HEAD`, then `main`, then
    `master`.
3. If none exist, ask the user which commit to use as the base.

Commits **after** the base are fixup-eligible. Commits **at or before** the
base are off-limits — fixing those up would rewrite published history. If
blame points at an off-limits commit, surface that thread to the user and
skip it (don't silently target the base commit).

## Step 2 — enumerate the hunks

Always operate on the combined staged+unstaged diff, so the user gets one
consistent set of fixup commits regardless of what they happened to stage:

```sh
git diff HEAD       # combined working-tree-vs-HEAD diff
```

For each modified file, walk the hunks. A hunk is the `@@ -a,b +c,d @@` block
plus its body. You need the per-hunk `-` (removed/changed) line ranges in the
**old** file (pre-change) — those are the lines you'll blame.

Skip:
- Untracked files (no blame possible — ask the user how to handle them; usually
    they belong in a fresh commit, not a fixup).
- Files that are pure additions (`new file mode`) — same: not a fixup, ask.
- Files that are pure deletions (`deleted file mode`) — blame the commit that
    last touched the file as a whole (`git log -1 --format=%H -- <path>`), but
    confirm with the user; deletions are often intentional new commits.
- Renames where the body is unchanged — no fixup needed.

## Step 3 — blame each hunk back to its origin commit

For each hunk in each file, find the commit that introduced the lines being
modified. Use `git blame` against `HEAD` on the **original** line range
(the `-` side of the hunk header):

```sh
git blame -L <old_start>,<old_end> --porcelain HEAD -- <path>
```

Parse the porcelain output and collect the set of distinct commit SHAs touching
those lines. Then:

- **Exactly one commit, and it's after the fixup base** → that's the fixup
    target for this hunk.
- **Multiple commits** → split the hunk by line so each sub-range goes to its
    own target. `git diff` doesn't split hunks for you; do it by writing a
    hand-built patch (see Step 4) for each contiguous run of lines that share a
    target.
- **Pure-addition hunk** (header has `-0,0`, only `+` lines) → there's nothing
    to blame. Look at the surrounding context lines: blame the line just before
    the insertion. If that line is from an in-scope commit, attribute the
    addition there. If it's ambiguous (e.g., insertion at top of file, or
    surrounding context is from the fixup base), ask the user.
- **Target is at or before the fixup base** → off-limits. Report to user and
    skip; don't target it.
- **Target is itself a fixup commit** (`^fixup! ` prefix) → walk past it to
    the commit it ultimately fixes up (strip the `fixup! ` prefix and find the
    matching subject, or use `git log --grep` / inspect the autosquash chain).
    Attribute to the original target so autosquash collapses cleanly.

Group hunks by target commit. The output is `{commit_sha: [hunks…]}`.

## Step 4 — stage and commit each group

For each target commit, in order from oldest to newest (so the user sees a
sensible commit history):

1. Build a patch containing only that group's hunks. The simplest robust
    approach: start from a clean index that matches HEAD, then apply just those
    hunks.

    ```sh
    # Reset the index to HEAD without touching the working tree
    git reset

    # Create a patch file for this group
    # (write the file headers + selected hunks to /tmp/fixup-<sha>.patch)
    git apply --cached /tmp/fixup-<sha>.patch
    ```

    If `git apply --cached` rejects the patch (line numbers drift when multiple
    hunks in the same file go to different targets), fall back to applying
    hunks one at a time, or use `git apply --cached --recount` /
    `--unidiff-zero` as needed. If that still fails, stop and tell the user
    which file/hunk couldn't be cleanly split — don't guess.

2. Verify only the intended changes are staged:

    ```sh
    git diff --cached --stat
    ```

3. Create the fixup commit:

    ```sh
    git commit --fixup=<target_sha> --no-verify=false
    ```

    (Don't pass `--no-verify` — let pre-commit hooks run. If a hook fails,
    surface the failure; don't bypass it.)

4. Move on to the next group. The remaining unstaged changes in the working
    tree should shrink with each commit.

After the last group, the working tree should be clean. If it isn't, something
was missed — show the user the leftover diff and ask.

## Step 5 — report

Print a summary the user can scan:

```
Target commit                                | File:hunk             | Status
---------------------------------------------+-----------------------+----------
abc1234 "Add user model"                     | app/models/user.rb @42| fixup committed (def456a)
abc1234 "Add user model"                     | app/models/user.rb @88| fixup committed (def456a)
e5f6789 "Wire up auth middleware"            | app/auth.rb @12       | fixup committed (789abcd)
(skipped) HEAD~7 is at/before fixup base     | README.md @3          | left in working tree
(skipped) untracked file                     | scripts/new.sh        | left in working tree
```

End with the exact follow-up command the user will likely run:

```sh
git rebase -i --autosquash <fixup_base>
```

…where `<fixup_base>` is the commit identified in Step 1 (or its parent — use
the parent so the base commit itself is in the rebase todo and autosquash can
reorder fixups under it).

## Notes & pitfalls

- **Don't squash merges into fixups.** If the fixup base is itself a merge
    commit, autosquash gets confusing. Warn the user and ask before proceeding.
- **Don't fixup across a force-push boundary.** If `@{upstream}` has commits
    HEAD doesn't (i.e., the branch has been force-pushed and the local copy is
    behind), stop and ask — fixups based on a divergent upstream usually aren't
    what the user wants.
- **Whitespace-only changes** still get blamed normally. If the user wants
    `-w` semantics (ignore whitespace when blaming), they'll say so; default to
    exact blame.
- **Binary files** can't be split by hunk. Attribute the whole file to the
    last commit that touched it; if that's off-limits, ask.
- **Generated/lockfile changes** (`Gemfile.lock`, `package-lock.json`, etc.)
    often span many commits' worth of intent. It's usually right to put them in
    a fixup targeting whichever commit changed the corresponding manifest — but
    if blame is scattered across many in-scope commits, ask the user rather
    than guessing.
- **Don't run `git rebase` yourself.** This skill produces fixup commits and
    stops. The user runs the autosquash rebase when they're ready.
