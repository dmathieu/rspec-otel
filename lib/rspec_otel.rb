# frozen_string_literal: true

require 'opentelemetry/sdk'
require 'opentelemetry-test-helpers'

module RspecOtel
  def self.exporter
    @exporter ||= OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
  end

  def self.record
    span_processor = OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter)

    OpenTelemetry::SDK.configure do |c|
      c.add_span_processor span_processor
    end

    yield
  ensure
    reset
  end

  def self.reset
    OpenTelemetry::TestHelpers.reset_opentelemetry
    @exporter = nil
  end
end

require 'rspec_otel/matchers'
require 'rspec_otel/rspec'
require 'rspec_otel/version'
