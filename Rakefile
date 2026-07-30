# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('lib', __dir__))

require 'rake/testtask'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)
task default: :spec

namespace :enforceable do
  desc 'Verify policies registered with Enforceable (configure ENFORCEABLE_WORLD and ENFORCEABLE_BINDING)'
  task :verify do
    require 'enforceable'
    Enforceable.runner!
    world = ENV.fetch('ENFORCEABLE_WORLD') { raise 'Set ENFORCEABLE_WORLD' }.to_sym
    binding_name = ENV.fetch('ENFORCEABLE_BINDING', 'pundit')
    binding = case binding_name
              when 'pundit' then Enforceable::Binding::Pundit.new
              when 'action_policy' then Enforceable::Binding::ActionPolicy.new
              when 'cancancan' then Enforceable::Binding::CanCanCan.new(ability: ->(actor) { Ability.new(actor) })
              else raise "Unknown ENFORCEABLE_BINDING: #{binding_name}"
              end
    report = Enforceable::Runner.new(binding: binding, world: world).run
    puts report.to_s(format: ENV.fetch('ENFORCEABLE_FORMAT', 'text'))
    abort 'Enforceable verification failed' if report.failed?
  end
end

desc 'Run the intentionally failing authorization demo'
task :demo do
  load File.expand_path('demo/demo.rb', __dir__)
end
