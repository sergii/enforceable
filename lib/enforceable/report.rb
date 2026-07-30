# frozen_string_literal: true

require 'json'

module Enforceable
  # Formats verification findings for people and CI.
  class Report
    STATE_COLUMN_WIDTH = 11

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
    def to_s(format: :text, color: $stdout.tty?, verbose: false)
      return JSON.generate(to_h) if format.to_sym == :json
      return clean_summary if clean? && !verbose

      text(color: color, verbose: verbose)
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

    def text(color:, verbose:)
      grouped = findings.group_by { |finding| [finding.policy_class, finding.rule] }
      groups = grouped.sort_by { |(policy, rule), entries| [entries.any? { |finding| !finding.match? } ? 0 : 1, policy.name.to_s, rule.to_s] }
      body = groups.map { |(policy, rule), entries| render_group(policy, rule, entries, color: color, verbose: verbose) }.join("\n\n")
      [status_summary, body + acknowledgements_text].reject(&:empty?).join("\n\n")
    end

    def render_group(policy, rule, entries, color:, verbose:)
      divergent = entries.reject(&:match?)
      warning = query_warning_line(entries)
      return healthy_group(policy, rule, entries) if divergent.empty? && warning.nil? && !verbose

      header = group_header(policy, rule, entries, divergent)
      rows = verbose || divergent.empty? ? entries : divergent
      actor_width = column_width(rows, :actor_name, 5, 20)
      subject_width = column_width(rows, :subject_name, 7, 32)
      lines = [header, '', table_header(actor_width, subject_width)]
      rows.each do |finding|
        rule_result = point_state(finding)
        scope_result = scope_state(finding)
        marker = finding.match? ? '' : '   ←'
        row = format(table_format(actor_width, subject_width), truncate(finding.actor_name, actor_width),
                     truncate(finding.subject_name, subject_width), rule_result, scope_result) + marker
        lines << colorize(row, finding, color)
      end
      append_hidden_match_note(lines, entries, rows, verbose)
      if divergent.empty?
        lines << warning if warning
        return lines.join("\n")
      end

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
      message = "  #{label}: #{finding.actor_name} / #{finding.subject_name} (#{finding.record.class}##{display_id(finding.record_id)}) — #{details}"
      source = source_hint(finding)
      lines = [message]
      lines << "    policy source: #{source}" if source
      lines << '    Expected: the scope must exclude this record.' if finding.leak?
      lines.join("\n")
    end

    def clean?
      findings.all?(&:match?) && query_warning_line(findings).nil?
    end

    def clean_summary
      policy_count = findings.map(&:policy_class).uniq.size
      "Enforceable: #{pluralize(findings.size, 'pair')} across #{pluralize(policy_count, 'policy', 'policies')} — no divergences."
    end

    def status_summary
      counts = []
      counts << pluralize(findings.count(&:leak?), 'data exposure')
      counts << pluralize(findings.count(&:error?), 'error')
      counts << pluralize(findings.count(&:narrow?), 'narrow-scope warning')
      counts.reject! { |count| count.start_with?('0 ') }
      state = failed? ? 'FAIL' : 'PASS'
      "Enforceable — #{pluralize(findings.size,
                                 'check')} across #{pluralize(findings.map(&:policy_class).uniq.size, 'policy', 'policies')}\n#{state}: #{counts.empty? ? 'no divergences' : counts.join(' · ')}"
    end

    def healthy_group(policy, rule, entries)
      "✓ #{policy.name}##{rule} — #{entries.size}/#{entries.size} checks agree"
    end

    def group_header(policy, rule, entries, divergent)
      return "Enforceable — #{policy.name}##{rule}" if divergent.empty?

      "DIVERGENCE — #{policy.name}##{rule} (#{pluralize(divergent.size, 'divergence')} across #{pluralize(entries.size, 'check')})"
    end

    def table_header(actor_width, subject_width)
      header = format(table_format(actor_width, subject_width), 'actor', 'record', 'policy', 'scope')
      "#{header}\n  #{'─' * (header.length - 2)}"
    end

    def table_format(actor_width, subject_width)
      "  %-#{actor_width}s  %-#{subject_width}s  %-#{STATE_COLUMN_WIDTH}s  %-#{STATE_COLUMN_WIDTH}s"
    end

    def append_hidden_match_note(lines, entries, rows, verbose)
      return if verbose

      hidden = entries.size - rows.size
      lines << "  … #{pluralize(hidden, 'matching check')} hidden; set ENFORCEABLE_VERBOSE=true for the full matrix" if hidden.positive?
    end

    def column_width(entries, attribute, minimum, maximum)
      [minimum, entries.map { |finding| finding.public_send(attribute).to_s.length }.max].max.clamp(minimum, maximum)
    end

    def truncate(value, width)
      text = value.to_s
      return text if text.length <= width

      "#{text[0, width - 1]}…"
    end

    def display_id(identifier)
      text = identifier.to_s
      text.length > 12 ? "#{text[0, 12]}…" : text
    end

    def point_state(finding)
      return 'error' if finding.error?

      finding.allowed ? 'allow' : 'deny'
    end

    def scope_state(finding)
      return 'error' if finding.error?

      finding.included ? 'include' : 'exclude'
    end

    def source_hint(finding)
      location = finding.policy_class.instance_method(finding.rule).source_location
      return unless location

      path, line = location
      path = path.delete_prefix("#{Dir.pwd}/") if path.start_with?("#{Dir.pwd}/")
      "#{path}:#{line}"
    rescue NameError
      nil
    end

    def pluralize(count, singular, plural = "#{singular}s")
      "#{count} #{count == 1 ? singular : plural}"
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
      {
        policy: finding.policy_class.name,
        rule: finding.rule,
        scope_name: finding.scope_name,
        actor: finding.actor_name,
        subject: finding.subject_name,
        rule_allowed: finding.allowed,
        scope_included: finding.included,
        direction: direction(finding),
        error: finding.error&.message,
        queries: finding.queries
      }
    end

    def direction(finding)
      return 'leak' if finding.leak?
      return 'narrow_scope' if finding.narrow?
      return 'error' if finding.error?

      'match'
    end
  end
end
