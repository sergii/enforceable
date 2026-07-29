# frozen_string_literal: true

require 'json'

module Enforceable
  # Formats verification findings for people and CI.
  class Report
    attr_reader :findings, :acknowledgements

    # Creates a report from runner output.
    def initialize(findings, acknowledgements = [], warn_on_narrow_scope: true, query_warning_threshold: 3)
      @findings = findings
      @acknowledgements = acknowledgements
      @warn_on_narrow_scope = warn_on_narrow_scope
      @query_warning_threshold = query_warning_threshold
    end

    # Returns true for errors, leaks, and configured narrow scopes.
    def failed?
      findings.any?(&:error?) || findings.any?(&:leak?) || (!@warn_on_narrow_scope && findings.any?(&:narrow?))
    end

    # Renders the report, optionally as JSON for CI.
    def to_s(format: :text, color: $stdout.tty?)
      return JSON.generate(to_h) if format.to_sym == :json
      return clean_summary if clean?

      text(color: color)
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
      divergent = entries.reject(&:match?)
      header = divergent.empty? ? "Enforceable — #{policy.name}##{rule}" : "Enforceable::Divergence — #{policy.name}##{rule}"
      lines = [header, '',
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
      warning = query_warning_line(entries)
      return (lines << warning).join("\n") if divergent.empty? && warning
      return lines.join("\n") if divergent.empty?

      lines << ''
      divergent.each { |finding| lines << explanation(finding) }
      lines << warning if warning
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

    def clean?
      findings.all?(&:match?) && query_warning_line(findings).nil?
    end

    def clean_summary
      policy_count = findings.map(&:policy_class).uniq.size
      "Enforceable: #{findings.size} pairs across #{policy_count} policies — no divergences."
    end

    def query_warning_line(entries)
      return unless @query_warning_threshold

      slow = entries.select { |finding| finding.queries.to_i >= @query_warning_threshold }
      return if slow.empty?

      details = slow.map { |finding| "#{finding.actor_name}/#{finding.subject_name}=#{finding.queries} SQL" }.join(', ')
      "\n  N+1 RISK (threshold: #{@query_warning_threshold} SQL/check): #{details}"
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
