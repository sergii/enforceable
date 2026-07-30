# frozen_string_literal: true

module Enforceable
  Declaration = Struct.new(:rule, :scope_name, :scope_options, :source_location, keyword_init: true)
  Acknowledgement = Struct.new(:rule, :reason, keyword_init: true)
  class DuplicateDeclarationError < StandardError
  end

  # Class methods made available to policies that include Enforceable.
  module DeclarationMethods
    # Declares a point rule and the named collection scope it must match.
    def enforceable(rule, scope_name:, scope_options: {})
      rule = rule.to_sym
      ensure_rule_is_undeclared!(rule)
      (@enforceable_declarations ||= []) << Enforceable::Declaration.new(
        rule: rule,
        scope_name: scope_name.to_sym,
        scope_options: scope_options,
        source_location: caller_locations(1, 1).first
      )
    end

    # Records an explicitly excluded rule and its reason.
    def not_enforceable(rule, reason:)
      rule = rule.to_sym
      ensure_rule_is_undeclared!(rule)
      (@enforceable_acknowledgements ||= []) << Enforceable::Acknowledgement.new(rule: rule, reason: reason)
    end

    # Returns declarations inherited from parent policies.
    def enforceable_declarations
      own = @enforceable_declarations || []
      own_acknowledgements = @enforceable_acknowledgements || []
      inherited = superclass.respond_to?(:enforceable_declarations) ? superclass.enforceable_declarations : []
      overridden_rules = own.map(&:rule) + own_acknowledgements.map(&:rule)
      inherited.reject { |declaration| overridden_rules.include?(declaration.rule) } + own
    end

    # Returns acknowledged exclusions inherited from parent policies.
    def enforceable_acknowledgements
      own = @enforceable_acknowledgements || []
      inherited = superclass.respond_to?(:enforceable_acknowledgements) ? superclass.enforceable_acknowledgements : []
      overridden_rules = own.map(&:rule) + (@enforceable_declarations || []).map(&:rule)
      inherited.reject { |acknowledgement| overridden_rules.include?(acknowledgement.rule) } + own
    end

    private

    def ensure_rule_is_undeclared!(rule)
      declarations = (@enforceable_declarations || []) + (@enforceable_acknowledgements || [])
      return unless declarations.any? { |declaration| declaration.rule == rule }

      raise Enforceable::DuplicateDeclarationError, "#{name || self} already declares #{rule}"
    end
  end
end
