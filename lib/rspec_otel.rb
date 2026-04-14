# frozen_string_literal: true

require 'opentelemetry/sdk'
require 'opentelemetry-test-helpers'
require 'opentelemetry-metrics-sdk'

module RspecOtel
  def self.exporter
    @exporter ||= OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
  end

  def self.metric_exporter
    @metric_exporter ||= OpenTelemetry::SDK::Metrics::Export::InMemoryMetricPullExporter.new
  end

  def self.record
    span_processor = OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter)

    OpenTelemetry::SDK.configure do |c|
      c.add_span_processor span_processor
    end

    meter_provider = OpenTelemetry::SDK::Metrics::MeterProvider.new
    meter_provider.add_metric_reader(metric_exporter)
    OpenTelemetry.meter_provider = meter_provider

    yield
  ensure
    reset
  end

  def self.reset
    OpenTelemetry::TestHelpers.reset_opentelemetry
    OpenTelemetry.meter_provider = OpenTelemetry::Internal::ProxyMeterProvider.new
    @exporter = nil
    @metric_exporter = nil
  end
end

require 'rspec_otel/matchers'
require 'rspec_otel/rspec'
require 'rspec_otel/version'
