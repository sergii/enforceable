# frozen_string_literal: true

module Enforceable
  # Describes actors and subjects used by a verification run.
  class World
    Entry = Struct.new(:name, :block, keyword_init: true)

    class << self
      # Defines and registers a named fixture world.
      def define(name, &block)
        world = new(name)
        world.instance_eval(&block)
        worlds[name.to_sym] = world
      end

      # Fetches a world by name.
      def fetch(name) = worlds.fetch(name.to_sym)

      # Holds registered worlds.
      def worlds = (@worlds ||= {})
    end

    attr_reader :name, :actors, :subjects

    # Creates an empty world.
    def initialize(name)
      @name = name
      @actors = []
      @subjects = []
    end

    # Adds a lazily evaluated actor fixture.
    def actor(name, &block) = @actors << Entry.new(name: name.to_sym, block: block)

    # Adds a lazily evaluated subject fixture.
    def subject(name, &block) = @subjects << Entry.new(name: name.to_sym, block: block)

    # Evaluates fixtures for this run.
    def materialize
      [actors.to_h { |entry| [entry.name, entry.block.call] }, subjects.to_h { |entry| [entry.name, entry.block.call] }]
    end
  end
end
