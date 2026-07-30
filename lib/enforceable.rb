# frozen_string_literal: true

require_relative 'enforceable/version'
require_relative 'enforceable/declaration'
require_relative 'enforceable/world'
require_relative 'enforceable/binding'

module Enforceable
  # Registers policy declarations; it has no runtime authorization behaviour.
  def self.included(base)
    base.extend DeclarationMethods
    policies << base unless policies.include?(base)
  end

  # Returns policy classes that opted in to verification.
  def self.policies
    @policies ||= []
  end

  # Configures the Rails verification task.
  def self.configure
    yield configuration
  end

  # Returns task configuration without loading test-only dependencies.
  def self.configuration
    @configuration ||= Configuration.new
  end

  # Clears global registrations, primarily for isolated test suites.
  def self.reset!
    @policies = []
    World.reset!
  end

  # Loads the test runner only when it is explicitly needed.
  def self.runner!
    require_relative 'enforceable/runner'
    require_relative 'enforceable/report'
  end

  # Holds optional configuration for framework integrations.
  class Configuration
    attr_accessor :world, :binding, :warn_on_narrow_scope, :query_warning_threshold

    def initialize
      @warn_on_narrow_scope = true
      @query_warning_threshold = 3
    end
  end
end

require_relative 'enforceable/railtie' if defined?(Rails::Railtie)
