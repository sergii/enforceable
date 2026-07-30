# frozen_string_literal: true

require 'active_record'
require 'enforceable'
Enforceable.runner!

binding_name = ENV.fetch('BINDING', 'pundit')

if binding_name == 'action_policy'
  require 'action_policy'
  require 'action_policy/rails/scope_matchers/active_record'
end

require 'cancan' if binding_name == 'cancancan'

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ActiveRecord::Schema.define do
  create_table(:workspaces) { |t| t.string :name }
  create_table(:users) do |t|
    t.string :role
    t.boolean :hiring_committee, default: false
    t.references :workspace
  end
  create_table(:departments) do |t|
    t.string :name
    t.references :workspace
  end
  create_table(:requisitions) do |t|
    t.boolean :confidential, default: false
    t.references :department
    t.references :workspace
  end
  create_table(:applications) do |t|
    t.references :requisition
    t.references :workspace
    t.boolean :confidential, default: false
  end
end

class Workspace < ActiveRecord::Base; end

class User < ActiveRecord::Base
  belongs_to :workspace

  def on_hiring_committee?(_requisition) = hiring_committee?
end

if defined?(ActionPolicy)
  class ActionApplicationPolicy < ActionPolicy::Base
    include Enforceable

    enforceable :show?, scope_name: :default

    def show?
      return false if record.requisition.confidential? && !user.on_hiring_committee?(record.requisition)

      user.workspace_id == record.workspace_id
    end

    # Deliberate bug: this must also exclude confidential requisitions.
    relation_scope do |relation|
      relation.where(workspace_id: user.workspace_id)
    end
  end
end

class Department < ActiveRecord::Base; belongs_to :workspace; end

class Requisition < ActiveRecord::Base
  belongs_to :workspace
  belongs_to :department
end

class Application < ActiveRecord::Base
  belongs_to :workspace
  belongs_to :requisition

  include Enforceable if defined?(CanCan)
  enforceable :read, scope_name: :default if defined?(CanCan)
end

if defined?(CanCan)
  class Ability
    include CanCan::Ability

    def initialize(user)
      can :read, Application, workspace_id: user.workspace_id
      cannot :read, Application, confidential: true unless user.hiring_committee?
    end
  end
end

class ApplicationPolicy
  include Enforceable

  enforceable :show?, scope_name: :default

  def initialize(user, record)
    (@user = user
     @record = record)
  end

  def show?
    return false if @record.requisition.confidential? && !@user.on_hiring_committee?(@record.requisition)

    @user.workspace_id == @record.workspace_id
  end

  class Scope
    def initialize(user, relation)
      (@user = user
       @relation = relation)
    end

    # Deliberate bug: this must also exclude confidential requisitions.
    def resolve = @relation.where(workspace_id: @user.workspace_id)
  end
end

Workspace.create!(name: 'main')

Enforceable::World.define(:ats) do
  actor(:recruiter) { User.create!(role: 'recruiter', workspace: Workspace.first, hiring_committee: false) }
  actor(:interviewer) { User.create!(role: 'interviewer', workspace: Workspace.first, hiring_committee: true) }
  actor(:outsider) { User.create!(role: 'outsider', workspace: Workspace.create!(name: 'other')) }
  subject(:normal_job_application) do
    Application.create!(workspace: Workspace.first, confidential: false,
                        requisition: Requisition.create!(workspace: Workspace.first,
                                                         department: Department.create!(workspace: Workspace.first), confidential: false))
  end
  subject(:confidential_job_application) do
    Application.create!(workspace: Workspace.first, confidential: true,
                        requisition: Requisition.create!(workspace: Workspace.first,
                                                         department: Department.create!(workspace: Workspace.first), confidential: true))
  end
end

binding, policies = case binding_name
                    when 'pundit'
                      [Enforceable::Binding::Pundit.new, [ApplicationPolicy]]
                    when 'action_policy'
                      [Enforceable::Binding::ActionPolicy.new, [ActionApplicationPolicy]]
                    when 'cancancan'
                      [Enforceable::Binding::CanCanCan.new(ability: Ability), [Application]]
                    else
                      raise "Unknown BINDING: #{binding_name}"
                    end
report = Enforceable::Runner.new(binding: binding, world: :ats, policies: policies).run
puts report.to_s(format: ENV.fetch('FORMAT', 'text'))
abort 'Demo intentionally fails: the scope leaks confidential applications' if report.failed?
