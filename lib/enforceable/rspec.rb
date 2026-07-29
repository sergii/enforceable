# frozen_string_literal: true

require 'enforceable'

module Enforceable
  # RSpec helpers for one readable example per registered policy.
  module RSpec
    # Defines verification examples for all opted-in policies.
    def verify_all_policies(world:, binding: Binding::Pundit.new, warn_on_narrow_scope: true)
      Enforceable.policies.each do |policy|
        it "keeps #{policy.name} point checks and scopes consistent" do
          report = Runner.new(binding: binding, world: world, warn_on_narrow_scope: warn_on_narrow_scope,
                              policies: [policy]).run
          expect(report).not_to be_failed, report.to_s
        end
      end
    end
  end
end
