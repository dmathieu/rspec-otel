# frozen_string_literal: true

require 'bundler/setup'
Bundler.setup

require 'rspec_otel'

RSpec.configure do |config|
  config.include RspecOtel::Matchers
end
