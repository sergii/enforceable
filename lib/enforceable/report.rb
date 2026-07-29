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
    def to_s(format: :text, color: $stdout.tty?)
      format.to_sym == :json ? JSON.generate(to_h) : text(color: color)
    end

    # Returns a machine-readable representation.
    def to_h
      {
        failed: failed?,
        findings: findings.map { |finding| finding_hash(finding) },
        acknowledged: acknowledgements.map do |policy, entry|
          { policy: policy.name, rule: entry.rule, reason: entry.reason }
        end
      }
    end

    private

    def text(color:)
      grouped = findings.group_by { |finding| [finding.policy_class, finding.rule] }
      grouped.map { |(policy, rule), entries| render_group(policy, rule, entries, color: color) }.join("\n\n") + acknowledgements_text
    end

    def render_group(policy, rule, entries, color:)
      lines = ["Enforceable::Divergence — #{policy.name}##{rule}", '',
               '  actor          subject             rule   scope', '  ─────────────────────────────────────────────────']
      entries.each do |finding|
        rule_result = if finding.error?
                        'ERROR'
                      else
                        (finding.allowed ? '✓' : '✗')
                      end
        scope_result = if finding.error?
                         'ERROR'
                       else
                         (finding.included ? '✓' : '✗')
                       end
        marker = finding.match? ? '' : '   ←'
        row = format('  %-14s %-19s %-6s %-6s%s', finding.actor_name, finding.subject_name, rule_result, scope_result, marker)
        lines << colorize(row, finding, color)
      end
      divergent = entries.reject(&:match?)
      return lines.join("\n") if divergent.empty?

      lines << ''
      divergent.each { |finding| lines << explanation(finding) }
      slow = entries.select { |finding| finding.queries.to_i > 2 }
      lines << "  N+1 RISK: #{slow.map { |finding| "#{finding.actor_name}/#{finding.subject_name}=#{finding.queries} SQL" }.join(', ')}" unless slow.empty?
      lines << ''
      lines << "  Fix the scope, fix the rule, or declare: not_enforceable :#{rule}, reason: \"...\""
      lines.join("\n")
    end

    def explanation(finding)
      label = if finding.leak?
                'DATA EXPOSURE — scope broader than rule'
              else
                finding.narrow? ? 'WARNING — rule broader than scope' : "ERROR — #{finding.error.class}: #{finding.error.message}"
              end
      details = if finding.error?
                  'policy or scope raised'
                else
                  "rule #{finding.allowed ? 'allowed' : 'denied'}; scope #{finding.included ? 'included' : 'excluded'}"
                end
      "  #{label}: #{finding.actor_name} / #{finding.subject_name} (#{finding.record.class}##{finding.record_id}) — #{details}"
    end

    def colorize(text, finding, color)
      return text unless color && !finding.match?

      "\e[#{finding.leak? || finding.error? ? 31 : 33}m#{text}\e[0m"
    end

    def acknowledgements_text
      return '' if acknowledgements.empty?

      "\n\nACKNOWLEDGED\n" + acknowledgements.map { |policy, item|
        "  #{policy.name}##{item.rule}: #{item.reason}"
      }.join("\n")
    end

    def finding_hash(finding)
      { policy: finding.policy_class.name, rule: finding.rule, scope: finding.scope, actor: finding.actor_name, subject: finding.subject_name,
        rule_allowed: finding.allowed, scope_included: finding.included, direction: if finding.leak?
                                                                                      'leak'
                                                                                    elsif finding.narrow?
                                                                                      'narrow_scope'
                                                                                    else
                                                                                      finding.error? ? 'error' : 'match'
                                                                                    end, error: finding.error&.message, queries: finding.queries }
    end
  end
end
