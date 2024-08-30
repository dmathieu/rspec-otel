# frozen_string_literal: true

require 'rspec/core'

RSpec.configure do |config|
  config.around(:each) do |example|
    if example.metadata[:rspec_otel_disable_tracing]
      example.run
    else
      RspecOtel.record do
        example.run
      end
    end
  end
end
