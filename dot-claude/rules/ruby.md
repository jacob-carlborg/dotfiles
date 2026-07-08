---
paths:
  - "**/*.rb"
  - "**/*.rake"
  - "**/Rakefile"
  - "**/Gemfile"
  - "**/*.gemspec"
  - "**/*.erb"
  - "**/*.haml"
  - "**/*.slim"
---

# Ruby coding style

- If the Ruby version allows (3.2+), always prefer `Data.define` over `Struct`.
  Check the project's `.ruby-version` or `Gemfile` before assuming availability;
  fall back to `Struct` on older Rubies.
- If a method declaration fits within a single line and within 80 columns, use
  endless method syntax (`def name(args) = body`). Otherwise use the standard
  `def ... end` form. Don't change existing methods unless explicitly told so.
- For single line blocks. For Ruby 3.4+, prefer implicit block argument.
  Older versions, use numbered block parameters.
- When adding a class or module in a new namespace, use the compact
  `class Namespace::Class` syntax instead of nested `module Namespace`
  blocks, and don't create an empty `module Namespace` file just to hold the
  namespace — assume Zeitwerk is used, which handles the namespace
  automatically. When adding to an existing namespace, follow the style that
  namespace already uses.

  ```ruby
  # Bad
  module Billing
    class Invoice
    end
  end

  # Good
  class Billing::Invoice
  end
  ```
