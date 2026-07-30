# frozen_string_literal: true

module Enforceable
  # Adapts Enforceable to an authorization library without changing semantics.
  class Binding
    # Raised when a binding cannot apply a requested named scope.
    class UnsupportedScopeName < StandardError; end
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

      def scope(actor, _rule, relation, policy_class: nil, scope_name: nil, **_opts)
        raise UnsupportedScopeName, "Pundit exposes one Scope per policy; cannot honor scope_name: #{scope_name.inspect}" if scope_name && scope_name != :default

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

    # Adapter for CanCanCan abilities and Active Record scopes.
    class CanCanCan < Binding
      def initialize(ability:)
        super()
        @ability = ability
      end

      def rules_for(resource_class) = resource_class.enforceable_declarations.map(&:rule)

      # RuboCop mistakes a wrapper around CanCanCan's predicate for a predicate method.
      # rubocop:disable Naming/PredicateMethod
      def check(actor, rule, record, **)
        ability_for(actor).can?(rule, record)
      end
      # rubocop:enable Naming/PredicateMethod

      def scope(actor, rule, relation, scope_name: nil, **)
        raise UnsupportedScopeName, "CanCanCan exposes one accessible_by scope; cannot honor scope_name: #{scope_name.inspect}" if scope_name && scope_name != :default

        relation.accessible_by(ability_for(actor), rule)
      end

      private

      def ability_for(actor)
        @ability.respond_to?(:call) ? @ability.call(actor) : @ability.new(actor)
      end
    end
  end
end
