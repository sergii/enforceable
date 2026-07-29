# frozen_string_literal: true

require 'json'

module Enforceable
  # Formats verification findings for people and CI.
  class Report
    attr_reader :findings, :acknowledgements

    # Creates a report from runner output.
    def initialize(findings, acknowledgements = [], warn_on_narrow_scope: true)
      @findings = findings
      @acknowledgements = acknowledgements
      @warn_on_narrow_scope = warn_on_narrow_scope
    end

    # Returns true for errors, leaks, and configured narrow scopes.
    def failed?
      findings.any?(&:error?) || findings.any?(&:leak?) || (!@warn_on_narrow_scope && findings.any?(&:narrow?))
    end

    # Renders the report, optionally as JSON for CI.
    def to_s(format: :text)
      format.to_sym == :json ? JSON.generate(to_h) : text
    end

    # Returns a machine-readable representation.
    def to_h
      { failed: failed?, findings: findings.map do |f|
        finding_hash(f)
      end, acknowledged: acknowledgements.map do |policy, entry|
             { policy: policy.name, rule: entry.rule, reason: entry.reason }
           end }
    end

    private

    def text
      grouped = findings.group_by { |f| [f.policy_class, f.rule] }
      grouped.map { |(policy, rule), entries| render_group(policy, rule, entries) }.join("\n\n") + acknowledgements_text
    end

    def render_group(policy, rule, entries)
      lines = ["Enforceable::Divergence — #{policy.name}##{rule}", '',
               '  actor          subject             rule   scope', '  ─────────────────────────────────────────────────']
      entries.each do |f|
        rule_result = if f.error?
                        'ERROR'
                      else
                        (f.allowed ? '✓' : '✗')
                      end
        scope_result = if f.error?
                         'ERROR'
                       else
                         (f.included ? '✓' : '✗')
                       end
        marker = f.match? ? '' : '   ←'
        lines << format('  %-14s %-19s %-6s %-6s%s', f.actor_name, f.subject_name, rule_result, scope_result, marker)
      end
      divergent = entries.reject(&:match?)
      return lines.join("\n") if divergent.empty?

      lines << ''
      divergent.each { |f| lines << explanation(f) }
      lines << ''
      lines << "  Fix the scope, fix the rule, or declare: not_enforceable :#{rule}, reason: \"...\""
      lines.join("\n")
    end

    def explanation(f)
      label = if f.leak?
                'DATA EXPOSURE — scope broader than rule'
              else
                f.narrow? ? 'WARNING — rule broader than scope' : "ERROR — #{f.error.class}: #{f.error.message}"
              end
      details = if f.error?
                  'policy or scope raised'
                else
                  "rule #{f.allowed ? 'allowed' : 'denied'}; scope #{f.included ? 'included' : 'excluded'}"
                end
      "  #{label}: #{f.actor_name} / #{f.subject_name} (#{f.record.class}##{f.record_id}) — #{details}"
    end

    def acknowledgements_text
      return '' if acknowledgements.empty?

      "\n\nACKNOWLEDGED\n" + acknowledgements.map { |policy, item|
        "  #{policy.name}##{item.rule}: #{item.reason}"
      }.join("\n")
    end

    def finding_hash(f)
      { policy: f.policy_class.name, rule: f.rule, scope: f.scope, actor: f.actor_name, subject: f.subject_name,
        rule_allowed: f.allowed, scope_included: f.included, direction: if f.leak?
                                                                          'leak'
                                                                        elsif f.narrow?
                                                                          'narrow_scope'
                                                                        else
                                                                          f.error? ? 'error' : 'match'
                                                                        end, error: f.error&.message, queries: f.queries }
    end
  end
end
