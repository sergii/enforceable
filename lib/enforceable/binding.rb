# frozen_string_literal: true

module Enforceable
  # Adapts Enforceable to an authorization library without changing semantics.
  class Binding
    # Returns declared authorization rule names for a policy.
    def rules_for(_policy_class) = raise NotImplementedError

    # Executes one point authorization check.
    def check(_actor, _rule, _record, policy_class: nil) = raise NotImplementedError

    # Returns the scope relation for one authorization rule.
    def scope(_actor, _rule, _relation, policy_class: nil, scope_name: nil, **_opts) = raise NotImplementedError

    # Builds an adapter from three callables.
    def self.custom(rules:, check:, scope:)
      Custom.new(rules, check, scope)
    end

    # Lambda-backed adapter for PORO policies.
    class Custom < Binding
      def initialize(rules, check, scope)
        super()
        @rules = rules
        @check = check
        @scope = scope
      end

      def rules_for(policy_class) = @rules.call(policy_class)
      def check(actor, rule, record, policy_class: nil) = @check.call(actor, rule, record, policy_class: policy_class)

      def scope(actor, rule, relation, policy_class: nil, scope_name: nil,
                **)
        @scope.call(actor, rule, relation, policy_class: policy_class, scope_name: scope_name, **)
      end
    end

    # Conventional Pundit adapter.
    class Pundit < Binding
      def rules_for(policy_class) = policy_class.enforceable_declarations.map(&:rule)
      def check(actor, rule, record, policy_class: nil) = policy_class.new(actor, record).public_send(rule)

      def scope(actor, _rule, relation, policy_class: nil, **_opts)
        policy_class.const_get(:Scope).new(actor, relation).resolve
      end
    end

    # Adapter for Action Policy style actor methods.
    class ActionPolicy < Binding
      def rules_for(policy_class) = policy_class.enforceable_declarations.map(&:rule)

      def check(actor, rule, record, policy_class: nil)
        policy_class.new(record, user: actor).apply(rule)
      end

      def scope(actor, _rule, relation, policy_class: nil, scope_name: nil,
                **opts)
        policy_class.new(nil, user: actor).apply_scope(
          relation,
          type: :active_record_relation,
          name: scope_name || :default,
          scope_options: opts.empty? ? nil : opts
        )
      end
    end
  end
end
