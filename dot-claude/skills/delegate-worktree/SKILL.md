---
name: delegate-worktree
description: Hand a piece of work to a fresh Claude Code session running in its own git worktree, driven from a new cmux workspace. Use when the user says "delegate this", "spin up a worktree and have it do X", "open a cmux workspace and implement Y there", or otherwise asks for work to be done by another session rather than in this one.
---

# Delegate to a worktree session

Open a new cmux workspace, start a Claude Code session in a fresh git worktree
inside it, and brief that session on the work. The current session stays free —
it hands off and reports the address, it does not implement the work itself.

## Steps

### 1. Pick a name

One name serves as the cmux workspace title, the git branch, the worktree
directory, and the session name. Derive it from the work, kebab-case, in the
style of the repo's existing branches — `beam-tracking-numbers-guard`,
`fix-receipt-advice-5954`, `issue-5607-sales-order-response-line-idempotency`.
Include the issue number when there is one. Check `cmux workspace list` first
and pick something that isn't already taken.

### 2. Create the workspace

```bash
CMUX_QUIET=1 cmux new-workspace --name <name> --cwd <repo-root> --focus false
```

Prints `OK workspace:<n>` — keep that ref for every later call. `--cwd` must be
the **main checkout** of the repo, not a worktree; `worktree create` branches
from wherever it is run. `--focus false` leaves the user where they were; drop
it if they asked to be taken to the new session.

`CMUX_QUIET=1` suppresses the legacy-alias notices some `cmux` subcommands
print.

### 3. Start the worktree session

```bash
CMUX_QUIET=1 cmux send --workspace workspace:<n> "worktree create <name>"
CMUX_QUIET=1 cmux send-key --workspace workspace:<n> enter
```

`cmux send` types the text but does not submit it — the separate `send-key
enter` is required.

`worktree create <name>` execs:

```
claude --worktree <name> --name <name> --remote-control <repo>/<name>
```

so the new session gets the worktree, the session name, *and* remote control —
which is what makes it addressable in step 4. Use the same `<name>` as the
workspace so the sidebar entry and the session name agree.

Confirm it booted before going further:

```bash
CMUX_QUIET=1 cmux read-screen --workspace workspace:<n> --lines 30
```

Look for the Claude banner, the worktree path under
`.claude/worktrees/<name>`, and `/remote-control is active`. Worktree creation
clones the database, so this takes a few seconds — if the screen still shows
the shell, wait and read again rather than re-sending the command. Do not use
foreground `sleep`; use a backgrounded `until` loop or just re-read.

### 4. Address the session

`ListAgents` and find the row named `<name>`. Then `SendMessage` to it.

The first send with the bare name will likely fail with a prompt to confirm the
ref — that's expected for cross-session peers, not an error. Re-send with the
ref exactly as the failure message printed it:

```
{"to": "<name> [d313c5]", "message": "..."}
```

### 5. Write the brief

The new session starts with **zero context** — it has none of this
conversation. Everything it needs goes in the message. A brief that says
"implement 1-3" or "fix the thing we discussed" wastes the handoff.

Include:

- **The task**, stated outright.
- **The findings so far** — the diagnosis, the reasoning, the evidence. Tell it
  to trust the conclusions but verify the code details itself, and to report
  back anything it finds to be wrong.
- **File paths with line numbers** for every place it needs to look, including
  paths in sibling repos when the reasoning spans them.
- **The numbered work items**, spelled out in full. Never carry over
  "1-3" — reproduce what those items actually were.
- **Out of scope** — anything the user is handling themselves, and any repo it
  must not touch.
- **How to work** — point at the applicable `CLAUDE.md` files, and restate the
  non-negotiables for that repo (TDD, the self-review pass, which lint and spec
  commands must pass, existing specs worth extending).
- **Where to stop** — commit on the branch, but check in before pushing or
  opening a PR unless the user said otherwise.

### 6. Report back

Tell the user the workspace ref, the session name and ref, the worktree path,
and one line on what the session was asked to do. Then stop — do not
implement the work in this session, and do not poll the delegated session for
progress unless asked. Its replies arrive on their own.

## Related

`worktree done [name]` removes a worktree, its branch, and its database when
the work is finished.
