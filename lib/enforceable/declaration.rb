# frozen_string_literal: true

module Enforceable
  Declaration = Struct.new(:rule, :scope_name, :scope_options, keyword_init: true)
  Acknowledgement = Struct.new(:rule, :reason, keyword_init: true)

  # Class methods made available to policies that include Enforceable.
  module DeclarationMethods
    # Declares a point rule and the named collection scope it must match.
    def enforceable(rule, scope_name:, scope_options: {})
      (@enforceable_declarations ||= []) << Enforceable::Declaration.new(rule: rule.to_sym, scope_name: scope_name.to_sym,
                                                                         scope_options: scope_options)
    end

    # Records an explicitly excluded rule and its reason.
    def not_enforceable(rule, reason:)
      (@enforceable_acknowledgements ||= []) << Enforceable::Acknowledgement.new(rule: rule.to_sym, reason: reason)
    end

    # Returns declarations inherited from parent policies.
    def enforceable_declarations
      inherited = superclass.respond_to?(:enforceable_declarations) ? superclass.enforceable_declarations : []
      inherited + (@enforceable_declarations ||= [])
    end

    # Returns acknowledged exclusions inherited from parent policies.
    def enforceable_acknowledgements
      inherited = superclass.respond_to?(:enforceable_acknowledgements) ? superclass.enforceable_acknowledgements : []
      inherited + (@enforceable_acknowledgements ||= [])
    end
  end
end
