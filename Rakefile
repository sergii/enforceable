# frozen_string_literal: true

require 'rake/testtask'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)
task default: :spec

namespace :enforceable do
  desc 'Verify policies registered with Enforceable (configure ENFORCEABLE_WORLD and ENFORCEABLE_BINDING)'
  task :verify do
    require 'enforceable'
    world = ENV.fetch('ENFORCEABLE_WORLD') { raise 'Set ENFORCEABLE_WORLD' }.to_sym
    binding_name = ENV.fetch('ENFORCEABLE_BINDING', 'pundit')
    binding = binding_name == 'pundit' ? Enforceable::Binding::Pundit.new : Enforceable::Binding::ActionPolicy.new
    report = Enforceable::Runner.new(binding: binding, world: world).run
    puts report
    abort 'Enforceable verification failed' if report.failed?
  end
end

desc 'Run the intentionally failing authorization demo'
task :demo do
  load File.expand_path('demo/demo.rb', __dir__)
end
