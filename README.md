# enforceable

Authorization bugs often hide in the gap between a policy’s point check and its collection scope. `enforceable` runs both for every actor/record fixture pair and reports disagreement—especially the dangerous case where a scope includes a record that the rule denies.

```ruby
Enforceable::Divergence — ApplicationPolicy#show?
  recruiter      confidential_app    ✗      ✓   ←
  DATA EXPOSURE — scope broader than rule: recruiter / confidential_app
```

## Install

Add `gem "enforceable", group: :test` and require `enforceable/runner` only in test support.

## Three-step setup

1. Include `Enforceable` in a Pundit/Action Policy policy—or in a CanCanCan resource model—and declare the action to compare, for example `enforceable :show?, scope_name: :default` or `enforceable :read, scope_name: :default`.
2. Define a `Enforceable::World` with actor and subject fixture blocks.
3. Call `Enforceable::Runner.new(binding:, world:).run`, or include `Enforceable::RSpec` and use `verify_all_policies`.

`not_enforceable :export?, reason: "session-only MFA state"` records a deliberate exclusion in the report.

Run the demos with `rake demo` (Pundit), `BINDING=action_policy rake demo` (Action Policy), or `BINDING=cancancan rake demo` (CanCanCan). The first two intentionally find a seeded leak; the CanCanCan demo verifies a matching real Ability.

`scope_name: :default` means the binding's default collection scope. Action Policy also supports named `relation_scope`s; Pundit has one `Scope` class per policy, and CanCanCan has one `accessible_by` relation per action. Pundit and CanCanCan reject any non-default scope name rather than silently checking a different scope.

## CanCanCan

CanCanCan keeps permissions in an `Ability` rather than model-specific policy classes. Include `Enforceable` in each Active Record resource you want to verify, then configure the binding with an Ability factory:

```ruby
class Application < ApplicationRecord
  include Enforceable

  enforceable :read, scope_name: :default
end

Enforceable.configure do |config|
  config.binding = Enforceable::Binding::CanCanCan.new(ability: Ability)
  config.world = :authorization
end
```

For each actor/record fixture pair, Enforceable compares `Ability#can?(:read, record)` with `Application.accessible_by(ability, :read)`. In a Rails application with a conventional top-level `Ability`, `ENFORCEABLE_BINDING=cancancan bin/rails enforceable:verify` configures that factory automatically.

## Rails task

Configure the fixture world and binding in an initializer, then run `bin/rails enforceable:verify` with `RAILS_ENV=test`. The task eager-loads policies, prints the report, and exits non-zero for leaks or errors.

Run `bin/rails "enforceable:verify[full]"` (or `bin/rails enforceable:full`) to print every actor/subject row, including healthy policies. `ENFORCEABLE_VERBOSE=true` is available for CI. The default output collapses healthy policies so divergences are easier to triage.
