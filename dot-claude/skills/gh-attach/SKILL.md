---
name: gh-attach
description: Upload a local image or video to GitHub and reference it so it renders inline in an issue, pull request, comment, or review — either through the `uploads.github.com` user-attachments endpoint or, on builds that have it, the `gh --attach` flag. Covers the accepted file types and size limits, how to reference an asset by hand, alt text after `#`, how a reference already in the body is rewritten in place, the flag combinations and permissions that are refused, and what a partial upload failure leaves behind. Use when attaching a screenshot, screen recording, or generated diagram to GitHub content, when a body would otherwise link a local path the reader cannot open, or before posting to uploads.github.com.
allowed-tools:
  - Bash(gh api:*)
  - Bash(gh issue:*)
  - Bash(gh pr:*)
  - Bash(gh repo:*)
  - Bash(gh auth:*)
  - Bash(grep:*)
  - Bash(ls:*)
  - Bash(stat:*)
---

# GitHub attachments

Images and video in issues and pull requests are served from a user-attachments
store. There are two ways to put a file there:

1. **`POST https://uploads.github.com/user-attachments/assets`** — works on
   every build, reaches everything, and leaves the markdown to you.
2. **`gh --attach`** — a repeatable flag on six commands that uploads *and*
   writes the markdown. Newer builds only.

`--attach` on this build: !`gh issue comment --help 2>/dev/null | grep -q -- '--attach' && echo present || echo absent`

Absent means the endpoint is the only way, and the `--attach` half of this file
does not apply — do not emit a command that will fail with `unknown flag`.
Present means `--attach` supersedes the endpoint for those six commands; the
endpoint still covers everything they do not reach.

## Ordering, and why it is the first thing here

**An upload cannot be undone and an asset cannot be deleted.** Every rule below
follows from that:

- Upload once the body is final and nothing is left that could cancel. With
  `--attach`, `gh` enforces this by checking credentials and permissions before
  any prompt or editor opens.
- An asset nothing references is stranded and permanent.
- An asset answers 404 until something references it, so **opening the URL
  proves nothing about the upload.** Do not verify an upload that way.
- Never re-run a failed attach blindly. Whatever already uploaded uploads
  again.

## The upload endpoint

It has no REST route and no documentation, so `gh api` reaches it by full URL.
`repository_id` takes the numeric REST id — `gh repo view --json id` returns
the GraphQL node id, which fails here.

```sh
set repo_id (gh api repos/{owner}/{repo} --jq .id)   # fish; bash: repo_id=$(...)

gh api --method POST \
  "https://uploads.github.com/user-attachments/assets?repository_id=$repo_id&name=picker.png&content_type=image/png" \
  --input ./picker.png --jq .url
```

The response is `{"url": "https://github.com/user-attachments/assets/<uuid>"}`.

`gh api` authenticates this host from the request URL and sets `Content-Length`
from `--input`, both of which the endpoint requires. Do **not** reach for
`--hostname`: `gh` prefixes `api.`, so `--hostname uploads.github.com` resolves
to `api.uploads.github.com` and never connects.

The token needs write access to that repository. Read-only access answers 404,
which makes a permission problem look like a missing repository.

## What GitHub will accept

The extension in `name` must agree with `content_type`, and nothing outside
this list uploads. Logs, archives, and PDFs have no path here.

| Kind | Extension | `content_type` | Limit |
| --- | --- | --- | --- |
| Image | `.png` | `image/png` | 10 MB |
| Image | `.jpg`, `.jpeg` | `image/jpeg` | 10 MB |
| Image | `.gif` | `image/gif` | 10 MB |
| Image | `.webp` | `image/webp` | 10 MB |
| Image | `.svg` | `image/svg+xml` | 10 MB |
| Video | `.mp4` | `video/mp4` | 100 MB or lower |
| Video | `.mov` | `video/quicktime` | 100 MB or lower |
| Video | `.webm` | `video/webm` | 100 MB or lower |

The video cap depends on the account plan, so the server may refuse a file
under 100 MB. `--attach` matches extensions case-insensitively and inspects
nothing but the extension — never the bytes.

## Referencing an asset by hand

An image is ordinary markdown. Escape `\`, `[`, and `]` in the alt text, and
flatten newlines to spaces; unescaped `](` closes the image early and repoints
it somewhere you did not choose.

```markdown
![Wide window](https://github.com/user-attachments/assets/<uuid>)
```

Video has no markdown syntax. GitHub renders a player when a bare asset URL is
**the whole of a paragraph** — nothing else on the line, blank lines either
side. Anywhere else, write it as a link instead.

## The `--attach` flag

Lands via the eight-PR stack tracked in
[cli/cli#14186](https://github.com/cli/cli/issues/14186) (top PR:
[#14184](https://github.com/cli/cli/pull/14184)).

| Command | Body comes from | Attach-only behaviour |
| --- | --- | --- |
| `gh issue comment` | `--body`, `--body-file`, stdin, editor | Posts a comment that is just the asset; no prompt |
| `gh pr comment` | same | same |
| `gh issue create` | `--body`, `--body-file`, stdin, editor | Asset appended to the body |
| `gh pr create` | same, plus `--fill` | Generated body is kept, asset appended below it |
| `gh issue edit` | `--body`, `--body-file`, editor | Keeps the existing body, appends the asset below it |
| `gh pr edit` | same | same |

An attachment is body *input* but not a body: with `--edit-last`, `gh pr edit`,
or `gh issue edit`, attaching does not replace the existing text.

### Argument form

```sh
gh issue comment 12 --attach './login.png#The login error state'
```

- Repeatable. Registered as a string array, not a string slice, so a comma in a
  filename is safe — but pass one `--attach` per file, never a comma-joined list.
- Alt text follows the path after `#`. Quote the whole argument in the shell so
  `#` is not read as a comment.
- Without alt text, an image falls back to the file's basename with the
  extension stripped and remaining dots turned into spaces (`login.v2.png` →
  `login v2`).
- `#` is legal in a filename, so the split prefers the longest prefix that
  actually exists on disk. `--attach './weird#name.png'` works when that file
  exists.
- Files upload in the order written, and append in that same order.
- **Alt text on a video is an error**, not something quietly dropped. A player
  has no alt attribute. Drop the `#…` for videos.

Refused before anything uploads: a path that does not exist, a directory,
anything that is not a regular file (a named pipe would block forever), an
empty file, an unsupported extension, a file over its limit, `--attach ''`
(what an unset shell variable produces), `--attach -` (stdin is not a file),
and the same file named twice — including a file plus a symlink or hard link to
it, since both would upload the same bytes twice.

### Where the asset ends up

If the body already references the local path, that reference is **rewritten in
place**. Otherwise the asset is **appended** as its own paragraph. Matching is
on the resolved absolute path, so `./login.png`, `login.png`, and an absolute
spelling all name the same attachment.

| What the body wrote | Image | Video |
| --- | --- | --- |
| `![alt](./f)` alone in a paragraph | destination swapped | replaced by the bare URL, so it plays |
| `![alt](./f)` inline in a sentence | destination swapped | degrades to `[alt](URL)`; a player cannot render mid-sentence |
| `[text](./f)` | destination swapped | destination swapped, stays a link |
| `![alt][label]` + `[label]: ./f` | rewritten once at the definition, so every use follows | **refused** — it would produce an image embed of a video |
| Inside a fenced block or an inline code span | untouched | untouched |
| A path nobody attached | untouched | untouched |

Alt text written in the body wins over the alt text passed to the flag. Link
text, titles, and formatting inside the label survive; only the destination
moves. The same file referenced twice uploads once and both references get the
same URL.

### Refused flag combinations

| Combination | Why |
| --- | --- |
| `--attach` + `--web` | The browser is doing the writing |
| `--attach` + `--delete-last` (comment) | Nothing to attach to |
| `--attach` + `--dry-run` (`gh pr create`) | A dry run must not upload, and an upload cannot be undone |
| `--attach` on more than one issue at once (`gh issue edit 1 2`) | One upload cannot be shared across several bodies |

Conflicts are checked while the flag is read, so this is uniform across all six
commands. The create commands also drop the browser-preview option from the
interactive menu when a file is attached.

### Preconditions, checked in this order

1. **Host.** GitHub Enterprise Server has no such endpoint —
   `attaching files is not supported on GitHub Enterprise Server`. GHEC
   tenants (`*.ghe.com`) do work and upload to their own `uploads.<host>`,
   which keeps data residency intact.
2. **Credential type.** Only OAuth, classic PAT, and fine-grained PAT can
   upload. Anything else (notably a GitHub Actions token) gives
   `unsupported authentication type`. `gh` never reads the token to decide
   this; it asks the config what kind is active.
3. **Repository role.** `ADMIN`, `MAINTAIN`, or `WRITE`. `READ` and `TRIAGE`
   get `attaching files requires write access to the repository`.

All three run before any prompt or editor opens, so a run that cannot upload
stops before the user types anything.

### Partial failure — what to tell the user

Uploading stops at the **first** failure; nothing after it is attempted. Then:

- **Nothing uploaded** → nothing is written. No comment posted, no issue or PR
  created, the existing body left exactly as it was, and nothing printed to
  stdout so a script does not read it as success.
- **Some uploaded** → the body **is** written anyway, carrying the assets that
  made it, and the command still exits non-zero naming the file that failed.
  This is intentional: markdown that does not reference an uploaded asset would
  orphan that asset permanently.
- A reference to a file that did not upload keeps its local path, so a
  partially failed run can leave a body containing links that do not resolve.
  That is a known, accepted cost — tell the user to fix that body by hand.

After a non-zero attach run, always check what actually got written before
retrying.

## Recipes

```sh
# Comment that is nothing but a screenshot
gh issue comment 12 --attach ./login.png

# Screenshot with alt text
gh issue comment 12 --attach './login.png#The login error state'

# Body that places the image itself — the reference is rewritten, not appended
gh issue comment 12 \
  --body 'Before the fix:

![the login screen](./login.png)' \
  --attach ./login.png

# Before/after plus a repro video (no alt text on the video)
gh pr comment 13 \
  --attach './before.png#Before the fix' \
  --attach './after.png#After the fix' \
  --attach ./repro.mp4

# New issue from a body file whose references get rewritten
gh issue create --title 'Login fails' --body-file ./report.md --attach ./login.png

# PR body built from commits, asset appended below it
gh pr create --fill --attach ./after.png

# Add a screenshot to an existing issue without touching its body
gh issue edit 12 --attach ./repro.png
```

## Out of `--attach`'s reach

Review comments, discussions, releases, and gists take no `--attach` and must
go through the endpoint: upload first, then write the markdown yourself and
post it with the relevant command. GitHub Enterprise Server has no endpoint at
all — direct the user to the web UI, where dragging the file into the comment
box produces the same kind of asset.

## Diagnosing an error

| Message | Cause |
| --- | --- |
| `is not a supported file type (supported: …)` | Extension not in the nine |
| `images must be under 10 MB` / `videos must be under 100 MB` | Over the local limit |
| `cannot set alt text on video` | Drop the `#…` |
| `… are the same file; attached files must be unique` | Duplicate path, symlink, or hard link |
| `cannot attach an empty path` | An unset shell variable reached `--attach` |
| `cannot embed a video as a reference-style image` | Rewrite the body to an inline `![…](./clip.mp4)` or a plain link |
| `attaching files is not supported on GitHub Enterprise Server` | Use the web UI |
| `unsupported authentication type` | Log in with OAuth or a PAT |
| `attaching files requires write access to the repository` | Role is READ or TRIAGE. Also what a 404 from the endpoint reports, because it answers 404 rather than 403 for an unwritable token |
| `could not determine which repository to attach files to` | The repository id was not resolved; report it as a `gh` bug |
| `is a directory` / `is not a regular file` / `is empty` | Point at a real, non-empty regular file |
| `Invalid name for request` (HTTP 400) | The endpoint got no usable `name` query param |
| HTTP 404 from the endpoint | Write access missing, or a GraphQL node id passed as `repository_id` |
