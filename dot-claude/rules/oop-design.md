---
paths:
  - "**/*.rb"
  - "**/*.rake"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.erb"
  - "**/*.haml"
  - "**/*.slim"
---

# Object-oriented design

Examples below are Ruby; the principles apply equally to JavaScript and
TypeScript.

## Polymorphism: one message, many receivers

Achieve polymorphism by sending one message that each receiver implements,
never by branching on type. A `case` on class, `is_a?`/`kind_of?` chains,
`respond_to?` sniffing, and `@type` flags are all the same coupling in
different syntax — a hidden duck type asking to be named.

Bad — the sender knows every concrete class, its methods, and its arguments;
every new payment type reopens this class:

```ruby
def process(payment_methods, order)
  payment_methods.each do |method|
    case method
    when CreditCard   then method.charge_card(order.total, order.currency)
    when PayPal       then method.send_invoice(order.total, order.buyer_email)
    when BankTransfer then method.initiate_transfer(order.total, order.iban)
    end
  end
end
```

Good — name the duck (`process_payment`) and let each receiver decide how:

```ruby
class PaymentProcessor
  def process(payments, order)
    payments.each { _1.process_payment(order) }
  end
end

class CreditCardPayment
  def process_payment(order) = charge_card(order.total, order.currency)
end

class PayPalPayment
  def process_payment(order) = send_invoice(order.total, order.buyer_email)
end
```

Adding a payment type is now a new class; the processor never changes. Trust
the duck: depend on the message contract, not the concrete class. Verify the
contract with shared tests (see the testing rules), never with defensive
`respond_to?` checks.

A `@type` flag driving `if`/`case` inside a class is the same smell — it
points to hidden subclasses (see Inheritance below).

## Choosing a mechanism

| Relationship   | Mechanism          | Use when |
|----------------|--------------------|----------|
| has-a          | Composition        | A whole built from pluggable parts — the default choice |
| behaves-like-a | Duck type / module | A role shared by unrelated classes; a module only when the role carries implementation, otherwise a plain duck type |
| is-a           | Inheritance        | Genuine specialization; keep hierarchies shallow and stable |

## Composition: building with parts

Compose parts that collaborate through one shared message; the whole never
knows the parts' concrete classes:

```ruby
class Report
  def initialize(title:, sections:)
    @title = title
    @sections = sections
  end

  def render = ["# #{@title}", *@sections.map(&:render)].join("\n\n")
end
```

`Report` only knows each section responds to `render`. `TextSection`,
`ChartSection`, and `TableSection` are independent, pluggable, and testable
in isolation.

## Factories: every `new` is a coupling point

When code must choose between concrete classes at runtime, give that decision
a single home. Never scatter `case`-and-`new` across call sites. Prefer a
mapping over a conditional, and use `fetch` for the error path:

```ruby
class ImporterFactory
  IMPORTERS = {
    ".csv"  => CsvImporter,
    ".json" => JsonImporter
  }.freeze

  def self.for(path)
    extension = File.extname(path)
    importer_class = IMPORTERS.fetch(extension) do
      raise ArgumentError, "Unsupported format: #{extension}"
    end
    importer_class.new(path)
  end
end
```

Adding a format is one class plus one hash entry; clients only talk to the
duck's interface. Likewise, centralize knowledge of which parts compose into
which wholes in a factory so configuration is not duplicated.

For application code, prefer injecting the collaborator over the classic
factory-method-via-inheritance pattern — composition gives one class instead
of a hierarchy. Reserve factory-method inheritance for framework-style
extension points.

## Inheritance: template methods and hooks

Use inheritance only for genuine specialization where the subclass is
everything the superclass is, plus more (Liskov). When building a hierarchy,
push all concrete behavior down into subclasses first, then promote only the
shared code back up — never leave concrete code in the superclass; leftovers
demoted later are far more expensive than promotions missed now.

Express the shared algorithm as a template method and let subclasses fill in
the varying steps. Every message the superclass (or a module) sends to its
implementers must be defined, even if only to raise:

```ruby
class Transaction
  def execute
    validate
    perform
    record
  end

  def validate
    raise "Invalid amount" if amount <= 0
    extra_validations
  end

  def perform = raise NotImplementedError, "#{self.class} must implement perform"
  def extra_validations = nil # hook
end

class Refund < Transaction
  def perform = payment_method.reverse_payment(self, original_transaction)

  def extra_validations
    raise "Refund exceeds original" if amount > original_transaction.amount
  end
end
```

Prefer hook methods (`post_initialize`, `extra_validations`) over forcing
subclasses to call `super` — subclasses should only know their own
specializations, never the parent's algorithm:

```ruby
class Transaction
  def initialize(amount:, payment_method:, order_id:, **opts)
    @amount = amount
    @payment_method = payment_method
    @order_id = order_id
    post_initialize(opts)
  end

  def post_initialize(opts) = nil # hook
end

class Refund < Transaction
  def post_initialize(opts)
    @original_transaction = opts.fetch(:original_transaction)
  end
end
```

A module's code must apply to every includer; if an includer would override a
method to say "not supported," it must not include the module. Don't inherit
from core classes (e.g. `Array`) — wrap and delegate instead. Don't create a
superclass or module merely to share code between otherwise unrelated
classes; that is a duck type or a composed collaborator.

## Dependency injection style

Constructors take keyword arguments with sensible defaults, so production
code stays terse and tests inject doubles. Expose dependencies through
private readers; make query methods private and memoized:

```ruby
class ReportsProcessor
  def initialize(repository: FulfillmentRepository.new, error_tracker: ErrorTracker.new)
    @repository = repository
    @error_tracker = error_tracker
  end

  def process = reportable.each { SendSingleReportJob.perform_async(_1.id) }

  private

  attr_reader :repository
  attr_reader :error_tracker

  def reportable = @reportable ||= repository.fulfilled.filter(&:reportable?)
end
```
