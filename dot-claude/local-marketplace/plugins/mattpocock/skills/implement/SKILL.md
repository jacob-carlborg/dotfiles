---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

Implement the work described by the user in the spec or tickets.

Use /tdd where possible, at pre-agreed seams.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

Once done, use /code-review to review the work.

Commit your work to the current branch.

## Before committing

1. Run `/review --fix` (the built-in `code-review` skill) once.
2. When the change has a browser-visible effect (a page, a UI flow, an HTTP endpoint), verify it in Safari with the Safari MCP tools: drive the affected flow and confirm it behaves as the spec or tickets describe. Fix what fails.
