# frozen_string_literal: true

namespace :enforceable do
  desc 'Verify declared authorization policies against collection scopes'
  task verify: :environment do
    Enforceable.runner!
    Rails.application.eager_load!

    config = Enforceable.configuration
    world = ENV['ENFORCEABLE_WORLD'] || config.world
    raise 'Configure Enforceable.world or set ENFORCEABLE_WORLD' unless world

    binding = config.binding || default_binding
    report = Enforceable::Runner.new(
      binding: binding,
      world: world,
      warn_on_narrow_scope: config.warn_on_narrow_scope,
      query_warning_threshold: config.query_warning_threshold
    ).run
    puts report.to_s(
      format: ENV.fetch('ENFORCEABLE_FORMAT', 'text'),
      verbose: ENV.fetch('ENFORCEABLE_VERBOSE', 'false') == 'true'
    )
    abort 'Enforceable verification failed' if report.failed?
  end

  def default_binding
    case ENV.fetch('ENFORCEABLE_BINDING', 'pundit')
    when 'pundit' then Enforceable::Binding::Pundit.new
    when 'action_policy' then Enforceable::Binding::ActionPolicy.new
    else raise "Unknown ENFORCEABLE_BINDING: #{ENV.fetch('ENFORCEABLE_BINDING', nil)}"
    end
  end
end
