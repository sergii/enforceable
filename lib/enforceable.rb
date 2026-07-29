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
end
