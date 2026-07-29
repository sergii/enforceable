# frozen_string_literal: true

require 'spec_helper'
require 'action_policy'
require 'action_policy/rails/scope_matchers/active_record'

class WidgetPolicy
  include Enforceable

  enforceable :show?, scope: :visible
  not_enforceable :export?, reason: 'MFA is session state'

  def initialize(user, record)
    (@user = user
     @record = record)
  end

  def show? = @record.visible? == @user[:admin]

  class Scope
    def initialize(user, relation)
      (@user = user
       @relation = relation)
    end

    def resolve = @relation
  end
end

class ActionWidgetPolicy < ActionPolicy::Base
  include Enforceable

  enforceable :show?, scope: :default

  def show?
    record.visible?
  end

  relation_scope do |relation|
    relation.where(visible: true)
  end
end

RSpec.describe Enforceable do
  before { Widget.delete_all }

  it 'reports a scope leak and acknowledged exclusions' do
    world = Enforceable::World.define(:widgets) do
      actor(:member) { { admin: false } }
      subject(:visible) { Widget.create!(name: 'visible', visible: true) }
    end
    report = Enforceable::Runner.new(binding: Enforceable::Binding::Pundit.new, world: world,
                                     policies: [WidgetPolicy]).run
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
    report = Enforceable::Runner.new(binding: binding, world: world, policies: [WidgetPolicy]).run
    expect(report).not_to be_failed
    expect(report.to_s).to include('WARNING')
  end

  it 'records policy exceptions instead of crashing' do
    binding = Enforceable::Binding.custom(
      rules: ->(_) { [:show?] },
      check: ->(*) { raise 'broken' },
      scope: ->(*) { Widget.all }
    )
    world = Enforceable::World.define(:broken) do
      actor(:a) { Object.new }
      subject(:widget) { Widget.create!(name: 'x') }
    end
    report = Enforceable::Runner.new(binding: binding, world: world, policies: [WidgetPolicy]).run
    expect(report.to_s).to include('ERROR')
  end

  it 'explains when a scope is not an Active Record relation' do
    binding = Enforceable::Binding.custom(
      rules: ->(_) { [:show?] },
      check: ->(*_) { true },
      scope: ->(*_) { [] }
    )
    world = Enforceable::World.define(:array_scope) do
      actor(:reader) { Object.new }
      subject(:widget) { Widget.create!(name: 'x') }
    end
    report = Enforceable::Runner.new(binding: binding, world: world, policies: [WidgetPolicy]).run
    expect(report.to_s).to include('scope returned Array, expected ActiveRecord::Relation')
  end

  it 'can reset globally registered policies and worlds' do
    Enforceable.reset!
    expect(Enforceable.policies).to be_empty
    expect(Enforceable::World.worlds).to be_empty
  ensure
    Enforceable.policies << WidgetPolicy
    Enforceable.policies << ActionWidgetPolicy
  end

  it 'uses Action Policy to apply a rule and Active Record relation scope' do
    actor = Object.new
    widget = Widget.create!(name: 'visible', visible: true)
    world = Enforceable::World.define(:action_widgets) do
      actor(:reader) { actor }
      subject(:visible) { widget }
    end
    report = Enforceable::Runner.new(binding: Enforceable::Binding::ActionPolicy.new, world: world,
                                     policies: [ActionWidgetPolicy]).run
    expect(report).not_to be_failed, report.to_s
  end
end
