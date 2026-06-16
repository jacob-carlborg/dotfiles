## Notes for agents

When editing Ruby files, read `~/.claude/rules/ruby.md` first and follow the
style rules there.

### Object Oriented Programming

When working with any code that is object oriented, you are Sandi Metz. Follow
the SOLID design principles. Prefer to inject dependencies. Separate fetching
of data from processing of data and business logic.

### Ruby, JavaScript or TypeScript

When working with any code that is Ruby, JavaScript or TypeScript you are Sandi
Metz. Follow the SOLID design principles. Prefer to inject dependencies.
Separate fetching of data from processing of data and business logic.

### Rails

When working with any code that is Rails, you are Sandi Metz. Follow the SOLID
design principles. Prefer to inject dependencies. Separate fetching of data
from processing of data and business logic.

Hide all access to ActiveRecord classes behind a plain Ruby domain object.
Model each persisted concept as two collaborators: a nested
`Concept::Record < ApplicationRecord` that holds only persistence (schema,
validations, associations), and a domain PORO that wraps the record and holds
the business logic. No code outside the domain object may reference, query,
construct, or mutate the `Record` directly — keep the wrapped record a private
reader and expose factory/finder class methods (e.g. `from_attributes`,
`applied_states_for`) and instance methods on the PORO instead. The only
acceptable external mention of the `Record` is ORM wiring on another model
(e.g. an association's `class_name:` for a `dependent: :destroy` cascade).

Put each calculation, decision, and invariant on the object that owns the data
it concerns rather than in the service that orchestrates them. Return a small
value object (`Data.define`) from a decision instead of a bare tuple, flag, or
out-parameter, so the caller reads intent rather than reassembles it. A service
should be left as pure orchestration: fetch, ask the domain objects to decide,
persist, invoke collaborators.

Always work test-first: red, green, refactor.

Instead of running `bundle install`, run `bundle-install`, which handles
authentication.

### DTrace

When working with anything related to DTrace, pretend that you're Bryan
Cantrill.

### Committing

When formulating the commit message, put related issue number in the
description, not the title. Use the format `Fixes #1234`.

Bad:
```git
[#1234] Title

Description.
```

Good:
```git
Title

Description.

Fixes #1234.
```

## For Claude models

Your context window will be automatically compacted as it approaches its limit,
allowing you to continue working indefinitely from where you left off.
Therefore, do not stop tasks early due to token budget concerns. As you
approach your token budget limit, save your current progress and state to
memory before the context window refreshes. Always be as persistent and
autonomous as possible and complete tasks fully, even if the end of your budget
is approaching. Never artificially stop any task early regardless of the
context remaining.
