## Screenshots

When the diff changes what a browser renders, the Evidence section shows screenshots of the affected page:

1. Load the Safari MCP screenshot tool with `ToolSearch` (`select:mcp__safari-mcp__screenshot`). It saves a PNG and returns its path; pass `savePath` to write it to the scratchpad directory.
2. Capture **After** on the current branch. Capture **Before** on the base branch, from a `git worktree`, when the app runs there; otherwise show only **After** and state why.
3. Reference each PNG in the body as `![<alt>](<path>)` and pass the same path to `gh pr create` or `gh pr edit` with `--attach <path>`. `gh` uploads the file and rewrites the reference to its URL.
