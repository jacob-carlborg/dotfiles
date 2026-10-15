## Before committing

1. Run `/review --fix` (the built-in `code-review` skill). Repeat until a run reports no new findings (nothing an earlier run didn't already report), stopping after five runs at most.
2. When the change has a browser-visible effect (a page, a UI flow, an HTTP endpoint), verify it in Safari with the Safari MCP tools: drive the affected flow and confirm it behaves as the spec or tickets describe. Fix what fails.
