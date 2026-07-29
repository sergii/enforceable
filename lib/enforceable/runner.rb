# frozen_string_literal: true

require_relative '../enforceable'
require_relative 'report'

module Enforceable
  # Executes policy declarations against every actor and subject in a world.
  class Runner
    class ScopeTypeError < StandardError
    end
    Finding = Struct.new(:policy_class, :rule, :scope, :actor_name, :subject_name, :actor, :record, :record_id,
                         :allowed, :included, :error, :queries, keyword_init: true) do
      # True when a denied record is included by the scope.
      def leak? = error.nil? && !allowed && included
      # True when an allowed record is absent from the scope.
      def narrow? = error.nil? && allowed && !included
      # True when the policy or scope raised.
      def error? = !error.nil?
      # True when both decisions agree.
      def match? = error.nil? && allowed == included
    end

    attr_reader :binding, :world, :warn_on_narrow_scope, :policies, :query_warning_threshold

    # Sets up a verification run using a binding and named or concrete world.
    def initialize(binding:, world:, warn_on_narrow_scope: true, policies: Enforceable.policies, query_warning_threshold: 3)
      @binding = binding
      @world = world.is_a?(World) ? world : World.fetch(world)
      @warn_on_narrow_scope = warn_on_narrow_scope
      @policies = policies
      @query_warning_threshold = query_warning_threshold
    end

    # Runs all registered policies and returns a report.
    def run
      ensure_active_record!
      findings = []
      acknowledgements = []
      in_transaction do
        actors, subjects = world.materialize
        policies.each do |policy|
          policy.enforceable_acknowledgements.each { |entry| acknowledgements << [policy, entry] }
          declared_rules = binding.rules_for(policy).map(&:to_sym)
          policy.enforceable_declarations.select { |declaration| declared_rules.include?(declaration.rule) }.each do |declaration|
            subjects.each do |subject_name, record|
              actors.each do |actor_name, actor|
                findings << verify(policy, declaration, actor_name, actor, subject_name, record)
              end
            end
          end
        end
        raise ::ActiveRecord::Rollback
      end
      Report.new(findings, acknowledgements, warn_on_narrow_scope: warn_on_narrow_scope,
                                             query_warning_threshold: query_warning_threshold)
    end

    private

    def verify(policy, declaration, actor_name, actor, subject_name, record)
      count_queries do
        allowed = binding.check(actor, declaration.rule, record, policy_class: policy)
        scoped = binding.scope(actor, declaration.rule, record.class.all, policy_class: policy,
                                                                          scope_name: declaration.scope, **declaration.scope_options)
        raise ScopeTypeError, "scope returned #{scoped.class}, expected ActiveRecord::Relation" unless scoped.is_a?(::ActiveRecord::Relation)

        included = scoped.where(id: record.id).exists?
        return Finding.new(policy_class: policy, rule: declaration.rule, scope: declaration.scope,
                           actor_name: actor_name, subject_name: subject_name, actor: actor, record: record, record_id: record.id, allowed: !!allowed, included: included, queries: query_count)
      end
    rescue StandardError => e
      Finding.new(policy_class: policy, rule: declaration.rule, scope: declaration.scope, actor_name: actor_name,
                  subject_name: subject_name, actor: actor, record: record, record_id: record.id, error: e, queries: query_count)
    end

    def ensure_active_record!
      return if defined?(::ActiveRecord::Base)

      raise LoadError, 'Enforceable::Runner requires ActiveRecord and is test-only'
    end

    def in_transaction(&)
      ::ActiveRecord::Base.transaction(requires_new: true, &)
    end

    def query_count = @query_count || 0

    def count_queries
      @query_count = 0
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |_name, _start, _finish, _id, payload|
        @query_count += 1 unless payload[:name] == 'SCHEMA'
      end
      yield
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end
  end
end
