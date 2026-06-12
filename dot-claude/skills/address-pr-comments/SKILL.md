---
name: address-pr-comments
description: Fetch every comment on a GitHub pull request (inline review comments, top-level review bodies, and issue-level PR comments), analyze each one, decide whether it is valid, and fix the issues it raises. Use when the user asks to "address PR comments", "respond to review feedback", "fix review comments", or similar, with or without a PR number/URL.
---

# Address PR comments

Pull every comment on a pull request, judge each one on its merits, and fix the
issues that are valid. Skip nits the user wouldn't want, push back on
suggestions that are wrong, and never silently apply a change you can't justify.

## Step 1 — resolve the PR

If the user provided a PR number or URL, use it directly. Otherwise look up the
PR for the current branch:

```sh
gh pr view --json number,url,headRefName,baseRefName,headRepositoryOwner,headRepository,title,state,isDraft
```

If `gh pr view` errors with "no pull requests found", stop and ask the user
which PR they mean — don't guess.

Capture `<owner>` and `<repo>` from the repo (use `gh repo view --json
owner,name` if needed) and `<number>` from the PR. You'll reuse them below.

Make sure the local branch matches the PR's head branch before editing
anything. If it doesn't, ask the user before checking out the PR branch — they
may have uncommitted work.

## Step 2 — fetch every comment

There are **three** distinct GitHub APIs and you need all of them. A "review
comment" left inline in code is *not* the same record as the review's summary
body, which is *not* the same as a general PR comment.

Run these in parallel:

```sh
# Inline review comments (anchored to a file + line + diff hunk)
gh api --paginate "repos/<owner>/<repo>/pulls/<number>/comments" \
  --jq '[.[] | {id, user: .user.login, path, line, original_line, side, commit_id, body, diff_hunk, in_reply_to_id, html_url, created_at}]'

# Review bodies (the summary text reviewers leave when submitting "Approve" / "Request changes" / "Comment")
gh api --paginate "repos/<owner>/<repo>/pulls/<number>/reviews" \
  --jq '[.[] | select(.body != "" and .body != null) | {id, user: .user.login, state, body, html_url, submitted_at}]'

# Issue-level PR comments (the general thread, not anchored to code)
gh api --paginate "repos/<owner>/<repo>/issues/<number>/comments" \
  --jq '[.[] | {id, user: .user.login, body, html_url, created_at}]'
```

Notes:

- `--paginate` is required — long reviews exceed one page and you must not
    silently truncate.
- `diff_hunk` is the few lines of context GitHub shows around the comment.
    Keep it; it tells you what code the reviewer was looking at.
- `original_line` matters when the PR was force-pushed after the comment was
    written: the `line` may be `null` (outdated) but `original_line` still
    anchors the intent.
- Threaded replies have `in_reply_to_id` set. Group them so you read the
    whole thread, not just the first message.

## Step 3 — filter out resolved / obsolete threads

Resolved threads usually shouldn't be re-addressed. The REST endpoints above
don't expose the resolved bit, so use GraphQL:


```sh
gh api graphql -f query='
  query($owner:String!,$repo:String!,$number:Int!) {
    repository(owner:$owner, name:$repo) {
      pullRequest(number:$number) {
        reviewThreads(first:100) {
          nodes {
            isResolved
            isOutdated
            comments(first:50) { nodes { databaseId body path line author { login } } }
          }
        }
      }
    }
  }' -F owner=<owner> -F repo=<repo> -F number=<number>
```

Drop any thread where `isResolved` is true. For `isOutdated` threads, read them
but treat them as low priority — the code they pointed at has already changed.


## Step 4 — group, then analyze each thread

Group inline comments by `(path, line, in_reply_to_id chain)` so you reason
about a *thread* (original + replies), not isolated messages. The reviewer's
first comment states the issue; replies may already contain the resolution, a
counter-argument, or the user's own decision.

For each thread, classify it into exactly one bucket:

| Bucket | Examples | Action |
|---|---|---|
| **Actionable bug/correctness** | "this will NPE when X is null", "off-by-one", "wrong variable" | Fix it. |
| **Actionable style/quality** | "extract this", "rename for clarity", "use the existing helper" | Fix it unless it conflicts with the codebase's conventions. |
| **Suggestion (GitHub `suggestion` block)** | A ` ```suggestion ` fenced block in the body | Apply verbatim if valid; otherwise treat as a normal suggestion. |
| **Question** | "why did you choose X over Y?" | Don't change code. Draft an answer for the user to post (or post it if the user asked you to reply). |
| **Praise / nit / FYI** | "nice!", "nit: extra space" | Skip unless explicitly nit-worthy and trivial. |
| **Disagreement / wrong** | Reviewer misread the code, or their suggestion would break something | Don't change code. Draft a respectful pushback explaining why. |
| **Out of scope** | "while you're here, also refactor Z" | Don't change code in this PR. Note for follow-up. |

Validity check before fixing anything:
1. **Re-read the current code at that path/line** — the file may already have
    changed since the comment was written.
2. **Verify the reviewer's claim is true.** If they say "this throws on empty
    input," try to construct that input mentally. If you can't, the comment may
    be wrong.
3. **Check the suggestion doesn't break tests or types.** Run the build/tests
    after the fix, not before declaring it done.

Don't apply a change just because someone with authority asked. The user is
responsible for the code; you're responsible for not making it worse.

## Step 5 — fix the valid issues

Apply fixes one thread at a time so each diff is reviewable. After each fix:
- Re-run the relevant tests / type-check / linter for that file.
- Commit the fix as a fixup commit targeting the commit that originally
    introduced the code the comment points at (see below).
- Note which thread the change addresses and the fixup commit SHA (you'll
    need both for the report).

If fixing one comment would conflict with another comment (reviewers sometimes
disagree), stop and ask the user which direction to take — don't silently pick
a side.

### Committing each fix as a fixup

Each fix becomes a `git commit --fixup=<target>` so the user can later run
`git rebase -i --autosquash` and fold every fix into the commit it amends.
Follow the same routing rules as the `fixup` skill (read
`~/.claude/skills/fixup/SKILL.md` for the full hunk-splitting and patch
mechanics); the short version:

1. **Determine the fixup-eligible range.** Only the PR's own commits are valid
    targets:

    ```sh
    git merge-base HEAD origin/<baseRefName>
    ```

    Commits after the merge-base are eligible. If blame points at or before
    the merge-base, the code predates the PR — don't create a fixup; report
    the thread and ask the user (the comment may really be asking for a new
    standalone commit).

2. **Find the target commit.** The comment itself anchors you: blame the
    lines the comment points at (and that your fix modifies), as they were
    before your fix:

    ```sh
    git blame -L <start>,<end> --porcelain HEAD -- <path>
    ```

    The comment's `commit_id` is *not* the target — it's just the head SHA the
    reviewer saw. Blame tells you which PR commit actually introduced the
    lines.

3. **Resolve fixup chains.** If blame lands on an earlier `fixup! …` commit,
    walk to the commit it ultimately fixes up and target that, so autosquash
    collapses everything into one place.

4. **Stage only this thread's fix and commit:**

    ```sh
    git add <files touched by this fix>   # or git apply --cached a per-hunk patch
    git commit --fixup=<target_sha>
    ```

    One fixup commit per thread. If a single thread's fix spans lines from
    multiple PR commits, split it into one fixup per target (per the `fixup`
    skill's hunk-splitting steps).

5. **Pure additions** (new files, new methods with no blamable old lines):
    blame the surrounding context lines to pick the target. If that's
    ambiguous, ask the user rather than guessing.

Let pre-commit hooks run (no `--no-verify`); if a hook fails, surface the
failure. Don't run the autosquash rebase yourself — leave the fixup commits
for the user to review and rebase.


## Step 6 — report back

Produce a concise table the user can scan:

```
Thread                              | Verdict         | Action
------------------------------------+-----------------+----------------------------------
src/auth.ts:42 (alice)              | valid bug       | fixup d4e5f6a → abc1234 "Add auth"
src/auth.ts:88 (bob)                | wrong — see note| pushback drafted
README.md:12 (alice)                | nit             | skipped
PR review body (carol)              | question        | answer drafted
```

Then list, for each "pushback drafted" or "answer drafted" item, the exact text
you'd post, so the user can review-and-send. Do not post anything to GitHub
yourself unless the user explicitly told you to.

If any fixup commits were created, end with the follow-up command:

```sh
git rebase -i --autosquash <merge-base>
```

…using the merge-base from Step 5 (or its parent, so the oldest target is in
the rebase todo). Don't run it yourself.


## Replying on GitHub (only if asked)

If the user says to post replies:

```sh
# Reply within an existing inline review thread
gh api "repos/<owner>/<repo>/pulls/<number>/comments/<comment_id>/replies" \
  -f body="<reply text>"

# Or general PR comment
gh pr comment <number> --body "<text>"
```

Don't resolve threads programmatically — let the user (or the reviewer) do that after reading your reply.

## Common pitfalls
- **Treating a review summary body as an inline comment.** They have different
    IDs and live at different endpoints. A review body that says "looks good
    except for the auth thing" usually points at an inline comment on the auth
    code; address the inline one, not the summary.
- **Acting on outdated comments.** If `line` is null and `original_line`
    points at code that no longer exists, the comment is probably already
    resolved by an earlier force-push. Note it as "outdated, no action" and move
    on.
- **Bundling unrelated fixes.** Each comment is its own thread; don't sneak
    refactors into the fix commit. The reviewer will look for the specific change
    they asked for.
- **Sweeping pre-existing dirt into a fixup.** If the working tree was dirty
    before you started fixing, those changes must not ride along in your fixup
    commits. Stage per-thread changes explicitly (per-file, or per-hunk with
    `git apply --cached`), never `git add -A`.
- **Blaming after the fix is applied.** Blame `HEAD`, not the working tree —
    once your edit is in place the old lines are gone and blame on the dirty
    file misattributes them.
- **Auto-applying `suggestion` blocks blindly.** They're convenient but can
    be wrong (especially across multi-line edits where line numbers drift). Read
    before applying.
- **Forgetting bot comments.** Dependabot, CodeRabbit, etc. produce a lot of
    noise. Skim them; most are skippable, but occasionally one flags a real CVE.
    Don't blanket-ignore.
