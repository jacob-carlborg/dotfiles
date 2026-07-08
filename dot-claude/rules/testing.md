---
paths:
  - "**/spec/**/*.rb"
  - "**/test/**/*.rb"
  - "**/*_spec.rb"
  - "**/*_test.rb"
---

# Testing rules

Test along the edges of an object, through its public interface — never its
private methods or internals. Test each thing once, in its proper place:

| Message           | Test it? | How |
|-------------------|----------|-----|
| Incoming          | Yes      | Assert on the return value / resulting state |
| Outgoing command  | Yes      | Mock: verify the message is sent with the right arguments |
| Outgoing query    | No       | The receiver's own spec covers it |
| Private (to self) | No       | Covered through the public methods that call it |

Never mock or stub the object under test — not even a single method on it
(no partial doubles on `subject`). If the object seems to need its own
methods stubbed to be testable, a collaborator is missing from its design:
extract the behavior into a collaborator and inject it.

Bad — peeks at a private method, so any rename or refactor breaks it even
when behavior is unchanged:

```ruby
it "charges the card" do
  expect(payment).to receive(:charge_card).with(100, "EUR")
  payment.process_payment(order)
end
```

Good — incoming message, asserted on its result:

```ruby
it "renders the title and its sections" do
  report = Report.new(title: "Q2", sections: [TextSection.new(data: "Strong growth.")])
  expect(report.render).to eq("# Q2\n\nStrong growth.")
end
```

Good — outgoing command, verified with a mock (and nothing more):

```ruby
it "tells the payment method to process the payment" do
  expect(payment_method).to receive(:process_payment).with(purchase)
  purchase.perform
end
```

Never stub or mock an outgoing query (`expect(section).to receive(:render)`)
— that couples the test to an implementation detail the receiver's spec
already covers.

## Matchers

- Prefer `have_attributes` over multiple separate expectations on the same
  object: `expect(subscription).to have_attributes(plan_code: "pro", seats: 5)`.
- When a test does need multiple expectations, annotate it with
  `:aggregate_failures` so every failure is reported, not just the first.
- Prefer predicate matchers (`be_*`, `have_*`) when the object has a
  predicate method: `expect(file).to be_open` instead of
  `expect(file.open?).to eq(true)`, `expect(params).to have_key(:id)`
  instead of `expect(params.has_key?(:id)).to eq(true)`.

## Test data

Set up data with factory_bot factories. A factory contains only what the
validations and database constraints need to pass — nothing more. If a test
asserts on a value, the test must set that value explicitly; never rely on a
factory default. If a value needs to be unique, the factory generates a
default with a truly random component — not a bare sequence. A sequence only
counts up within a single process, so it restarts from the beginning every
time the server, console, or seed script boots and collides with existing
data. Combine the sequence with randomness (or use a UUID/`SecureRandom`
value) so the default is unique across processes, not just within one test
run:

```ruby
# Bad — restarts at 1 on every boot, collides outside the test suite
sequence(:email) { |n| "user#{n}@example.com" }

# Good — the random component makes it unique across processes
sequence(:email) { |n| "user-#{n}-#{SecureRandom.hex(4)}@example.com" }
```

## Verifying doubles

Use verifying doubles so stubs stay anchored to real signatures — a naive
`double` keeps passing when the real contract changes, and the suite lies:

```ruby
subject(:processor) { described_class.new(repository:, error_tracker:, factory:) }

let(:repository) { instance_double(Pubsub::MessageRepository) }
let(:error_tracker) { class_spy(Sentry) }
let(:factory) { instance_double(Pubsub::MessageProcessorFactory) }
```

## Roles and hierarchies: shared_examples

Document duck types and shared role/inheritance contracts with
`shared_examples` — a duck type without shared tests is only a verbal
agreement. Every class playing the role includes the same examples, so a new
player that forgets a method fails immediately:

```ruby
RSpec.shared_examples "transaction line role" do
  it { is_expected.to respond_to(:reportable?) }
  it { is_expected.to respond_to(:calculate_price) }
  it { is_expected.to respond_to(:new_record) }
end

RSpec.describe FulfillmentLine do
  it_behaves_like "transaction line role"
end
```

Keep shared examples in `spec/support/shared_examples/`, one file per role.

Test an abstract superclass through a minimal concrete subclass defined in
the spec (`TransactionDouble < Transaction`), and assert that abstract hooks
raise `NotImplementedError` on the base class.

## Pain is a design signal

If a test is painful to set up or drags in many collaborators, treat it as a
design smell in the code — usually missing dependency injection or an object
that knows too much — not as a testing problem to be worked around.
