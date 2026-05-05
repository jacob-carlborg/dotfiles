# Ruby coding style

Apply these rules to all Ruby files (`*.rb`, `*.rake`, `Rakefile`, `Gemfile`,
`*.gemspec`, etc.).

- If the Ruby version allows (3.2+), always prefer `Data.define` over `Struct`.
  Check the project's `.ruby-version` or `Gemfile` before assuming availability;
  fall back to `Struct` on older Rubies.
- If a method declaration fits within a single line and within 80 columns, use
  endless method syntax (`def name(args) = body`). Otherwise use the standard
  `def ... end` form.
- For single line blocks. For Ruby 3.4+, prefer implicit block argument.
  Older versions, use numbered block parameters.
