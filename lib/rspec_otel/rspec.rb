# frozen_string_literal: true

require 'rspec/core'
require 'rspec/expectations'

RSpec.configure do |config|
  config.before(:suite) do
    span_processor = OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(RspecOtel.exporter)

    OpenTelemetry::SDK.configure do |c|
      c.add_span_processor span_processor
    end
  end

  config.around(:each) do |example|
    example.run
    RspecOtel.exporter.reset
  end
end
