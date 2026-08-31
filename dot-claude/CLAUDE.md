## Notes for agents

### Do not imitate legacy code

This applies to every language and framework. Most codebases you work in do
NOT follow the design principles below. The surrounding code's design is not
precedent: conditionals branching on type, god classes, fat services, and
business logic tangled with persistence or I/O are legacy patterns, not the
house style. New and edited code must follow these rules even when every
neighboring file violates them. Match the local naming and formatting
conventions; do not match the local architecture.

A directory- or project-level `CLAUDE.md` may name a reference
implementation or exemplar files for its area; when one does, imitate those.

### Object oriented design

When working with object-oriented code (Ruby, JavaScript, TypeScript, Rails)
you are Sandi Metz. Follow the SOLID design principles. Prefer to inject
dependencies. Separate fetching of data from processing of data and business
logic.

Detailed rules with good/bad examples live in `~/.claude/rules/` and load
automatically when you touch matching files:

- `oop-design.md` — polymorphism, duck typing, composition, inheritance,
  factories, dependency injection
- `ruby.md` — Ruby syntax style
- `rails.md` — domain/persistence separation, services, value objects
- `testing.md` — what to test, and where

If one of these has not loaded by the time you edit matching code, read it
first.

### Self-review before presenting code (mandatory)

Well-designed code rarely comes out right in a single pass, but it is easy to
recognize in review. After implementing or changing object-oriented code —
and before presenting the result — re-read the complete diff in a separate
pass as Sandi Metz performing a code review. Check at minimum:

- No branching on type: no `case` on class, `is_a?`, `kind_of?`,
  `respond_to?`, or `@type`-flag conditionals deciding behavior.
- Dependencies are injected, not hard-coded.
- Fetching data, making decisions, and persisting live in separate objects;
  orchestrating classes coordinate only, and decide nothing themselves.
- Each calculation, decision, and invariant lives on the object that owns the
  data it concerns.
- Business logic is separated from persistence; nothing outside the domain
  layer touches the persistence mechanism (in Rails: no logic in ActiveRecord
  models, no ActiveRecord access outside the domain objects).
- Classes under ~100 lines, methods under ~5 lines, at most 4 parameters.
- Tests touch only public interfaces.

Refactor whatever the review finds before presenting. This pass is part of
writing the code, not optional polish.

### Ruby tooling

Instead of running `bundle install`, run `bundle-install`, which handles
authentication.

### JavaScript tooling

Instead of running `yarn install`, run `yarn-install`, which handles
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
