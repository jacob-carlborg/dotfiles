---
name: comment-audit
description: Find an alternative to every comment in the just-changed code — undo the workaround it justifies, delete it, say it in code, enforce it with a test, or move it to an ADR.
argument-hint: "[commit, range, or path; defaults to the current changes]"
disable-model-invocation: true
---

# Comment audit

The goal is code that needs no comments. Go through every comment in the
changes made in this session, or in the working-tree diff if this session made
none. When `$ARGUMENTS` is given, look at that instead.

Treat every comment as a fig leaf until shown otherwise. An explanatory comment
is a safety valve: it makes a workaround look acceptable because "it's
explained". For each one, ask how the code would have been written if comments
were banned, and whether the workaround would have been taken at all.

Be aggressive. The comment has to earn its place, not the alternative.

For each comment, give your opinion on which alternative fits. Try them in this
order; the first that fits wins:

- **Undo the workaround.** The comment justifies code that isn't the
  straightforward way to do it. Describe the proper fix that removes both the
  workaround and the need to explain it.
- **Delete it.** It says nothing the code doesn't already say, or the reader
  can infer it from the code, the tests, or the commit history.
- **Say it in code.** A better name, an extracted method, or a type would carry
  the meaning.
- **Enforce it with a test.** The comment states an invariant or expected
  behavior. Name the test that would fail if it were broken.
- **Move it to an ADR.** The comment records a decision and why it was made,
  with alternatives that were rejected. A comment justifying a workaround lands
  here only after undoing it has been ruled out, and the ADR records why.

Keep a comment only when none of these fit and the reason it records lives
outside this codebase, such as a bug in a dependency or a quirk of an external
API. Say why for each one kept.

Number the findings sequentially, starting at 1, one number per comment, so I
can refer to them by number (e.g. "apply 1, 3 and 5"). Give each finding's
`file:line`, the comment, the chosen alternative, and the reasoning.

Do not edit anything. Present the opinions and let me choose what to apply.
