# frozen_string_literal: true

require 'rails/railtie'

module Enforceable
  # Loads Enforceable rake tasks in Rails applications.
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.expand_path('../tasks/enforceable.rake', __dir__)
    end
  end
end
