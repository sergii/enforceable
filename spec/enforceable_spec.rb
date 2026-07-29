# frozen_string_literal: true

require 'spec_helper'

class WidgetPolicy
  include Enforceable
  enforceable :show?, scope: :visible
  not_enforceable :export?, reason: 'MFA is session state'

  def initialize(user, record) = (@user = user
                                  @record = record)

  def show? = @record.visible? == @user[:admin]

  class Scope
    def initialize(user, relation) = (@user = user
                                      @relation = relation)

    def resolve = @relation
  end
end

RSpec.describe Enforceable do
  before { Widget.delete_all }

  it 'reports a scope leak and acknowledged exclusions' do
    world = Enforceable::World.define(:widgets) do
      actor(:member) { { admin: false } }
      subject(:visible) { Widget.create!(name: 'visible', visible: true) }
    end
    report = Enforceable::Runner.new(binding: Enforceable::Binding::Pundit.new, world: world).run
    aggregate_failures 'leak report' do
      expect(report).to be_failed
      expect(report.to_s).to include('DATA EXPOSURE')
      expect(report.to_s).to include('ACKNOWLEDGED')
    end
  end

  it 'keeps reverse scope mismatches as warnings by default' do
    widget = Widget.create!(name: 'visible', visible: true)
    binding = Enforceable::Binding.custom(
      rules: ->(_) { [:show?] },
      check: ->(_, _, _, **) { true },
      scope: ->(_, _, relation, **) { relation.none }
    )
    world = Enforceable::World.define(:narrow) do
      actor(:a) { Object.new }
      subject(:widget) { widget }
    end
    report = Enforceable::Runner.new(binding: binding, world: world).run
    expect(report).not_to be_failed
    expect(report.to_s).to include('WARNING')
  end

  it 'records policy exceptions instead of crashing' do
    binding = Enforceable::Binding.custom(rules: ->(_) { [:show?] }, check: lambda { |*_|
      raise 'broken'
    }, scope: lambda { |*_|
         Widget.all
       })
    world = Enforceable::World.define(:broken) do
      actor(:a) { Object.new }
      subject(:widget) { Widget.create!(name: 'x') }
    end
    expect(Enforceable::Runner.new(binding: binding, world: world).run.to_s).to include('ERROR')
  end

  it 'uses the Action Policy adapter actor API' do
    actor = Object.new
    relation = Widget.where(visible: true)
    actor.define_singleton_method(:allowed_to?) { |rule, record| rule == :show? && record.visible? }
    actor.define_singleton_method(:authorized_scope) { |input, type:| type == :visible ? input.where(visible: true) : input.none }
    widget = Widget.create!(name: 'visible', visible: true)
    binding = Enforceable::Binding::ActionPolicy.new
    expect(binding.check(actor, :show?, widget)).to be(true)
    expect(binding.scope(actor, :show?, relation, scope_name: :visible)).to include(widget)
  end
end
