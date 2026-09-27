---
name: delegate-worktree
description: Hand a piece of work to a fresh Claude Code session running in its own git worktree, driven from a new cmux workspace. Use when the user says "delegate this", "spin up a worktree and have it do X", "open a cmux workspace and implement Y there", or otherwise asks for work to be done by another session rather than in this one.
---

# Delegate to a worktree session

Open a new cmux workspace, start a Claude Code session in a fresh git worktree
inside it, and brief that session on the work. The current session stays free —
it hands off and reports the address, it does not implement the work itself.

The two sessions are **fully disconnected** after the handoff. The brief goes
in as the new session's initial prompt; nothing is sent to it afterwards, and
nothing comes back. If a live link were wanted, a subagent would do — the whole
point of this skill is that there is none.

**Never** use `ListAgents` or `SendMessage` on the delegated session, before or
after it boots. `SendMessage` to a peer session subscribes this session to its
replies, which is exactly the coupling this skill exists to avoid.

## Steps

### 1. Pick a name

One name serves as the cmux workspace title, the git branch, the worktree
directory, and the session name. Derive it from the work, kebab-case, in the
style of the repo's existing branches — `beam-tracking-numbers-guard`,
`fix-receipt-advice-5954`, `issue-5607-sales-order-response-line-idempotency`.
Include the issue number when there is one. Check `cmux workspace list` first
and pick something that isn't already taken.

### 2. Write the brief

The new session starts with **zero context** — it has none of this
conversation. Everything it needs goes in the brief. A brief that says
"implement 1-3" or "fix the thing we discussed" wastes the handoff.

Write it to `<scratchpad>/<name>-brief.md`, in this session's scratchpad
directory. It is a temporary handoff file: the new session reads it into its
context as its first action and then deletes it, so nothing lingers.

Include:

- **The task**, stated outright.
- **The findings so far** — the diagnosis, the reasoning, the evidence. Tell it
  to trust the conclusions but verify the code details itself, and to tell the
  user about anything it finds to be wrong.
- **File paths with line numbers** for every place it needs to look, including
  paths in sibling repos when the reasoning spans them.
- **The numbered work items**, spelled out in full. Never carry over
  "1-3" — reproduce what those items actually were.
- **Out of scope** — anything the user is handling themselves, and any repo it
  must not touch.
- **How to work** — point at the applicable `CLAUDE.md` files, and restate the
  non-negotiables for that repo (TDD, the self-review pass, which lint and spec
  commands must pass, existing specs worth extending).
- **Where to stop** — commit on the branch, then ask the user *in its own
  session* before pushing or opening a PR unless the user said otherwise. Make
  clear that it reports to the user, not to the session that wrote the brief —
  that session is gone as far as it is concerned.

### 3. Create the workspace

```bash
CMUX_QUIET=1 cmux new-workspace --name <name> --cwd <repo-root> --focus false
```

Prints `OK workspace:<n>` — keep that ref for every later call. `--cwd` must be
the **main checkout** of the repo, not a worktree; `worktree create` branches
from wherever it is run. `--focus false` leaves the user where they were; drop
it if they asked to be taken to the new session.

`CMUX_QUIET=1` suppresses the legacy-alias notices some `cmux` subcommands
print.

### 4. Start the worktree session with the brief

```bash
CMUX_QUIET=1 cmux send --workspace workspace:<n> "worktree create <name> 'Read the brief at <scratchpad>/<name>-brief.md, delete that file, then carry out the brief.'"
CMUX_QUIET=1 cmux send-key --workspace workspace:<n> enter
```

`cmux send` types the text but does not submit it — the separate `send-key
enter` is required. Keep the quoted prompt to that one line: `cmux send`
turns `\n` into Enter, so the brief itself must never be typed through it.

`worktree create <name> [claude args...]` execs:

```
claude --worktree <name> --name <name> --remote-control <repo>/<name> [claude args...]
```

so the trailing quoted string becomes the new session's initial prompt, and it
reads the brief file as its first action. Use the same `<name>` as the
workspace so the sidebar entry and the session name agree.

Confirm it booted:

```bash
CMUX_QUIET=1 cmux read-screen --workspace workspace:<n> --lines 30
```

Look for the Claude banner, the worktree path under
`.claude/worktrees/<name>`, and the session starting on the brief. Worktree
creation clones the database, so this takes a few seconds — if the screen still
shows the shell, wait and read again rather than re-sending the command. Do not
use foreground `sleep`; use a backgrounded `until` loop or just re-read.

This screen read is the last contact with the delegated session.

### 5. Report back

Tell the user the workspace ref, the session name, the worktree path, and one
line on what the session was asked to do. Then stop — do
not implement the work in this session, do not read its screen again, and do
not poll it for progress. It reports to the user in its own workspace.

## Related

`worktree done [name]` removes a worktree, its branch, and its database when
the work is finished.
