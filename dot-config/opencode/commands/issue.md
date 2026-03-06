---
description: Fetch a GitHub issue description
---

Fetch the description of an issue from GitHub using the `gh` CLI tool.

The argument is: $ARGUMENTS

Follow these rules to determine which issue to fetch:

1. **If an argument is provided**, parse it as follows:
   - If it matches the pattern `owner/repo#NUMBER` (e.g. `rails/rails#12345`), fetch issue NUMBER from that specific repository.
   - If it is a plain number (e.g. `42`), fetch that issue number from the default repository (see rule 2).
   - If $ARGUMENTS is empty, present a list of issues to choose from (see rule 3).

2. **Determine the default repository** by running these git commands:
   - First try: !`git remote get-url upstream 2>/dev/null`
   - Fall back to: !`git remote get-url origin 2>/dev/null`
   - Extract the `owner/repo` from the remote URL (strip any `https://github.com/` prefix or `git@github.com:` prefix and `.git` suffix).

3. **If no issue number is given** ($ARGUMENTS is empty), list open issues from the default repository for the user to choose from:
   - Run `gh issue list --repo OWNER/REPO --state open --limit 20 --sort created --json number,title,createdAt --order desc` to get the 20 most recent open issues.
   - Present the list to the user using the interactive question tool (mcp_question) with each issue as an option, formatted as `#NUMBER: TITLE`.

4. **Fetch the selected issue** by running:
   ```
   gh issue view NUMBER --repo OWNER/REPO --json title,body,number,state,labels,assignees,milestone,url
   ```

5. **Present the issue** clearly with:
   - Issue number and title
   - URL
   - State, labels, assignees, and milestone (if any)
   - The full issue body/description

Do NOT make any file changes. This is a read-only informational command.
