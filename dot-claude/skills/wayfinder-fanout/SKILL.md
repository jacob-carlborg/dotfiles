---
name: wayfinder-fanout
description: Fan a Wayfinder map out into parallel Claude Code sessions — one new cmux workspace per frontier ticket, each running /wayfinder on its ticket in its own git worktree, all collected in a new cmux workspace group. Use when the user gives a Wayfinder map issue (label `wayfinder:map`) and asks to fan it out, scale it out, work the tickets in parallel, or open a session per ticket.
---

# Fan a Wayfinder map out into sessions

Take a Wayfinder map issue, find its frontier tickets, and open one cmux
workspace per ticket. Each workspace runs `claude-swap run`, which starts a
Claude Code session in its own git worktree with `/mattpocock:wayfinder` on that
ticket as the initial prompt. The workspaces go in one new workspace group. The
user then drives every session from its own workspace.

The new sessions are **fully disconnected** from this one. Each gets
everything it needs from its initial prompt and from the tracker. Nothing is sent
to them afterwards, and nothing comes back. This session launches them,
confirms they booted, reports, and stops.

**Never** use `ListAgents` or `SendMessage` on the launched sessions, before or
after they boot. `SendMessage` to a peer session subscribes this session to its
replies, which is the coupling this skill exists to avoid.

## Steps

### 1. List the frontier

```bash
<skill-dir>/scripts/frontier <map-url>
```

It accepts the map's URL or `owner/repo#number` and prints one line per open
child ticket, tab-separated: number, status, URL, title. The status is
`frontier` (open, unblocked, unclaimed), `blocked:<n>,…` (the open tickets
blocking it) or `claimed:<login>,…` (the assignees). It exits non-zero if the
issue is not labelled `wayfinder:map`.

Only `frontier` tickets get a session. Blocked tickets can't be resolved yet, and
claimed ones already have someone on them. That also makes the skill safe to
re-run: every launched session claims its ticket first thing, so a later run
skips it. If there are no frontier tickets, say so and stop.

### 2. Find the checkout

The sessions run in the map repo's **main checkout**, not a worktree:
`claude --worktree` branches from wherever it starts, and `claude-swap run`
picks the account from the directory's mapping. If this session is in that repo
(`gh repo view --json nameWithOwner` matches the map's `owner/repo`), take the
first path from `git worktree list`. Otherwise ask the user where the repo is
checked out.

### 3. Pick the names

- **Group:** `#<map-number> <short map name>`, e.g. `#1 AirDC++ Mac v1 spec`
  for "Wayfinder: v1 spec for a Mac-native AirDC++ App". Drop the
  `Wayfinder:` prefix, since the group is obviously that.
- **Workspace title:** `#<number> <short noun phrase>`, three to five words
  that tell the tickets apart in the sidebar, e.g. `#7 Daemon TLS trust` for
  "How does the App decide to trust the Daemon's TLS certificate?".
- **Session name:** `wayfinder-<number>-<kebab-case phrase>`, the same phrase,
  e.g. `wayfinder-7-daemon-tls-trust`. It serves as both the worktree name and
  the Claude Code session name, exactly the same string for both. The prefix
  keeps them together in `git worktree list` for cleanup.

These strings get typed into the user's fish shell inside single quotes, so
leave out `'`, `"`, `\`, `$` and backticks. Check `cmux workspace-group list`
and `git worktree list` for clashes first.

### 4. Create the group

```bash
CMUX_QUIET=1 cmux workspace-group create --name '<group>' --cwd <repo-root>
```

Prints `OK workspace_group:<g>`. cmux gives the group a generated anchor
workspace, a plain shell in `<repo-root>` that serves as the group header. That
is how the user's other groups look too, so leave it.

### 5. Launch one session per ticket

For each frontier ticket, in the order `frontier` printed them:

```bash
CMUX_QUIET=1 cmux new-workspace --name '<workspace-title>' --cwd <repo-root> --focus false --group workspace_group:<g> --group-placement end
```

Prints `OK workspace:<n>`. Keep that ref. Then start the session:

```bash
CMUX_QUIET=1 cmux send --workspace workspace:<n> "claude-swap run -- --worktree <session-name> --name <session-name> '/mattpocock:wayfinder Work ticket <ticket-url> on map <map-url>'"
CMUX_QUIET=1 cmux send-key --workspace workspace:<n> enter
```

`cmux send` types the text but does not submit it, so the separate
`send-key enter` is required. Everything after `--` goes to `claude`:
`--worktree` gives the session its own checkout under
`.claude/worktrees/<session-name>`, `--name` gives the session the same name,
and the quoted string is its initial prompt.
Isolation matters here. Prototype tickets write code and research tickets create
`research/<name>` branches, so sessions sharing one checkout would switch
branches under each other.

The prompt names both the ticket and the map. `/wayfinder` loads the map
first, and a bare ticket URL could be mistaken for one. Wayfinder is plugin
skill `mattpocock:wayfinder` with `disable-model-invocation`, so it only runs
as a typed slash command, as it is here.

`--focus false` leaves the user where they were.

### 6. Confirm they booted

```bash
CMUX_QUIET=1 cmux read-screen --workspace workspace:<n> --lines 30
```

For each workspace, look for the Claude banner, the worktree path, and
`/mattpocock:wayfinder` starting on the ticket. If a screen still shows the
shell, read it again rather than re-sending the command. Do not use foreground
`sleep`; use a backgrounded `until` loop or just re-read. If a session failed
to start, say which one and why, and don't retry it on a guess.

These screen reads are the last contact with the launched sessions.

### 7. Report back

Give the user the group ref and name, then a table with one row per launched
session: ticket (its name linked to its URL), workspace ref, and session name. Then
list the tickets that were skipped and why (blocked by which tickets, or claimed
by whom). Then stop. Do not work any ticket in this session, do not read the
screens again, and do not poll for progress.

## Related

- Re-run this skill as tickets close. The next frontier gets its own group.
- `cmux workspace-group delete workspace_group:<g> --close-workspaces` closes
  the group and every workspace in it once the sessions are done.
- `git worktree list | grep wayfinder-` finds the worktrees left behind.
  Remove each with `git worktree remove` and delete the branch it had
  checked out.
