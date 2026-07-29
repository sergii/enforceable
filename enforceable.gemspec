# frozen_string_literal: true

require_relative 'lib/enforceable/version'

Gem::Specification.new do |spec|
  spec.name = 'enforceable'
  spec.version = Enforceable::VERSION
  spec.summary = 'Test policy checks against collection scopes'
  spec.authors = ['Enforceable contributors']
  spec.files = Dir['lib/**/*.rb', 'README.md', 'Rakefile', 'LICENSE.txt']
  spec.required_ruby_version = '>= 3.2'
  spec.add_development_dependency 'activerecord', '>= 7.0'
  spec.add_development_dependency 'rake', '>= 13.0'
  spec.add_development_dependency 'rspec', '>= 3.13'
  spec.add_development_dependency 'rubocop', '>= 1.60'
  spec.add_development_dependency 'sqlite3', '>= 1.6'
end
