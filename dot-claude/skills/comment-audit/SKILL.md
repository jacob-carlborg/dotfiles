---
name: comment-audit
description: Find an alternative to every comment in the just-changed code — delete it, undo the workaround it justifies, enforce it with a test, or move it to an ADR.
argument-hint: "[commit, range, or path; defaults to the current changes]"
disable-model-invocation: true
---

# Comment audit

The goal is code that needs no comments. Go through every comment in the
changes made in this session, or in the working-tree diff if this session made
none. When `$ARGUMENTS` is given, look at that instead.

For each comment, give your opinion on which alternative fits:

- **Delete it.** It says nothing the code doesn't already say.
- **Undo the workaround.** The comment justifies a workaround. Describe the
  proper fix that removes both the workaround and the need to explain it.
- **Say it in code.** A better name, an extracted method, or a type would carry
  the meaning.
- **Enforce it with a test.** The comment states an invariant or expected
  behavior. Name the test that would fail if it were broken.
- **Move it to an ADR.** The comment records a decision and why it was made,
  with alternatives that were rejected.

Keep a comment only when none of these fit, and say why.

Number the findings sequentially, starting at 1, one number per comment, so I
can refer to them by number (e.g. "apply 1, 3 and 5"). Give each finding's
`file:line`, the comment, the chosen alternative, and the reasoning.

Do not edit anything. Present the opinions and let me choose what to apply.
