# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rspec_otel/version'

Gem::Specification.new do |spec|
  spec.name        = 'rspec-otel'
  spec.version     = RspecOtel::VERSION
  spec.authors     = ['Damien MATHIEU']
  spec.email       = ['42@dmathieu.com']

  spec.summary     = 'RSpec matchers for the OpenTelemetry framework'
  spec.description = 'RSpec matchers for the OpenTelemetry framework'
  spec.homepage    = 'https://github.com/dmathieu/rspec-otel'
  spec.license     = 'MIT'

  spec.files = Dir.glob('lib/**/*.rb') + Dir.glob('*.md') + ['LICENSE']
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 3.0'

  spec.add_dependency 'opentelemetry-api', '~> 1.0'
  spec.add_dependency 'opentelemetry-sdk', '~> 1.0'
  spec.add_dependency 'opentelemetry-test-helpers'
  spec.add_dependency 'rspec-core', '~> 3.0'

  spec.metadata['rubygems_mfa_required'] = 'true'
end
