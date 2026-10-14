---
description: Creates a pull request and monitors CI
---

Create a pull request for the current branch, then watch its CI checks in the
background (`gh pr checks --watch`). When a check fails, fix the cause, push,
and watch again.

Stop when every check passes, or when the same check has failed twice for a
reason you can't fix on this branch. Finish by reporting which checks passed
and which failed, and why.
