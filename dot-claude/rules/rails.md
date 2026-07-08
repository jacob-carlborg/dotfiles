---
paths:
  - "**/app/**/*.rb"
  - "**/app/**/*.erb"
  - "**/app/**/*.haml"
  - "**/app/**/*.slim"
  - "**/db/**/*.rb"
---

# Rails design rules

## Domain / persistence separation

ActiveRecord classes hold ONLY persistence: schema, validations,
associations — no business logic. No code outside the owning domain object
may reference, query, construct, or mutate an ActiveRecord class directly:
not controllers, not jobs, not views, not other services. The only
acceptable external mention of a record class is ORM wiring on another model
(e.g. an association's `class_name:` for a `dependent: :destroy` cascade).

Model each persisted concept as two collaborators in two files: a
`Concept::Record < ApplicationRecord` holding the persistence, and a domain
PORO wrapping the record and holding the business logic. This keeps the
framework out of the business logic entirely — the domain object's file
contains plain Ruby only. There is no separate repository object — the
domain object's class-level factory/finder methods play the repository role,
and they are the only place `Record` is queried or constructed. Keep the
wrapped record behind a private reader and expose only the attributes
callers actually need; the rest of the ActiveRecord attribute surface stays
hidden.

`Record` is the seam between the persistence layer and the domain layer, and
ActiveRecord details must not leak past it. Except for the most trivial
cases (like `find`), the domain object does not compose ActiveRecord query
methods (`where`, `order`, `joins`, …) itself — the `Record` exposes an
intention-revealing interface (class methods) and the domain object talks to
that interface.

```ruby
# app/models/subscription/record.rb — persistence only, the only framework code
class Subscription::Record < ApplicationRecord
  self.table_name = "subscriptions"

  belongs_to :customer, class_name: "Customer::Record"

  def self.expiring_within(period) = where(expires_on: ..period.from_now)
end

# app/models/subscription.rb — business logic only, plain Ruby
class Subscription
  def self.from_attributes(**attributes) = new(Record.new(**attributes))

  def self.expiring_within(period)
    Record.expiring_within(period).map { new(_1) }
  end

  def initialize(record)
    @record = record
  end

  def renewable? = record.cancelled_at.nil? && record.expires_on.future?

  def renew
    record.update!(expires_on: record.expires_on + 1.year)
  end

  private

  attr_reader :record
end
```

Domain entities are plain classes, not `Data.define` — an entity often needs
to grow into an inheritance hierarchy later, which `Data` does not support.
Reserve `Data.define` for value objects.

## Where things live

Everything domain lives in `app/models`, organized by concept: the entity in
`app/models/subscription.rb` and its `Record`, collaborators, roles, and
value objects under `app/models/subscription/`. "Model" means domain model, not
"ActiveRecord subclass". There is no `app/services` directory in the
preferred layout — an orchestrating class is a domain collaborator with a
domain name (`Account::Seeder`, `Notifier::CardEventNotifier`), never a
`*Service`, namespaced under the concept it works on.

In legacy applications that already have `app/services`: put new classes in
`app/models` anyway and never add files to `app/services`. When
substantially reworking an existing service, move it to `app/models` under a
domain name in its own commit, separate from behavior changes.

## Orchestrators coordinate, domain objects decide

Put each calculation, decision, and invariant on the object that owns the
data it concerns, not in the orchestrator that coordinates them. An
orchestrating collaborator is pure coordination: fetch, ask the domain
objects to decide, persist, invoke collaborators.

```ruby
def process
  report_failed(failed_transactions)
  reportable_transactions.each { SendReportJob.perform_async(_1.id) }
end

private

def fulfillments
  @fulfillments ||= Fulfillment
    .fulfilled(within: fulfilled_within)
    .filter(&:reportable?) # the domain object decides, not the service
end
```

If an orchestrator computes something from a domain object's data, that
computation is on the wrong object — move it.

## Return value objects from decisions

Return a small value object (`Data.define`) from a decision instead of a bare
tuple, flag, or out-parameter, so the caller reads intent rather than
reassembles it:

```ruby
LineError = Data.define(*%i[code message field line_id])

def validate = validate_price + validate_quantity

private

def validate_price
  return [] if price_excluding_vat

  [
    LineError.new(
      code: "NO_PRICE_EX_VAT",
      message: "Line has no price excluding VAT",
      field: "price_excluding_vat",
      line_id: id
    )
  ]
end
```

## Migrations

When creating migrations, give every new table and every new column a brief
database-level comment describing it — one short sentence, like the examples
below, not a paragraph:

```ruby
create_table :subscriptions, comment: "Customers' running plan subscriptions" do |t|
  t.string :plan_code, comment: "Identifies the plan in the billing system"
  t.date :expires_on, comment: "Last day the subscription is active"
end

add_column :subscriptions, :seats, :integer,
  comment: "Number of licensed users"
```

## Workflow

Always work test-first: red, green, refactor.
