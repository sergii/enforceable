# frozen_string_literal: true

require_relative 'lib/enforceable/version'

Gem::Specification.new do |spec|
  spec.name = 'enforceable'
  spec.version = Enforceable::VERSION
  spec.summary = 'Test policy checks against collection scopes'
  spec.description = 'A test-only verifier that detects disagreement between authorization policy checks and collection scopes.'
  spec.authors = ['Serhii']
  spec.email = ['serhii@users.noreply.github.com']
  spec.homepage = 'https://github.com/sergii/enforceable'
  spec.license = 'MIT'
  spec.metadata = {
    'bug_tracker_uri' => 'https://github.com/sergii/enforceable/issues',
    'changelog_uri' => 'https://github.com/sergii/enforceable/blob/main/CHANGELOG.md',
    'source_code_uri' => 'https://github.com/sergii/enforceable',
    'rubygems_mfa_required' => 'true'
  }
  spec.files = Dir['lib/**/*.rb', 'README.md', 'Rakefile', 'LICENSE.txt', 'CHANGELOG.md']
  spec.required_ruby_version = '>= 3.2'
  spec.add_development_dependency 'action_policy', '>= 0.7'
  spec.add_development_dependency 'activerecord', '>= 7.0'
  spec.add_development_dependency 'pundit', '>= 2.3'
  spec.add_development_dependency 'rake', '>= 13.0'
  spec.add_development_dependency 'rspec', '>= 3.13'
  spec.add_development_dependency 'rubocop', '>= 1.60'
  spec.add_development_dependency 'sqlite3', '>= 1.6'
end
