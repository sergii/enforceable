# enforceable

Authorization bugs often hide in the gap between a policy’s point check and its collection scope. `enforceable` runs both for every actor/record fixture pair and reports disagreement—especially the dangerous case where a scope includes a record that the rule denies.

```
Enforceable::Divergence — ApplicationPolicy#show?
  recruiter      confidential_app    ✗      ✓   ←
  DATA EXPOSURE — scope broader than rule: recruiter / confidential_app
```

## Install

Add `gem "enforceable", group: :test` and require `enforceable/runner` only in test support.

## Three-step setup

1. Include `Enforceable` in policies and declare `enforceable :show?, scope_name: :default`.
2. Define a `Enforceable::World` with actor and subject fixture blocks.
3. Call `Enforceable::Runner.new(binding:, world:).run`, or include `Enforceable::RSpec` and use `verify_all_policies`.

`not_enforceable :export?, reason: "session-only MFA state"` records a deliberate exclusion in the report.

Run the demo with either adapter: `rake demo` (Pundit) or `BINDING=action_policy rake demo` (Action Policy). Both use the real framework APIs.

`scope_name: :default` means the binding's default collection scope. Action Policy also supports named `relation_scope`s; Pundit has one `Scope` class per policy and rejects any non-default scope name rather than silently checking a different scope.
