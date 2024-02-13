# frozen_string_literal: true

require 'opentelemetry/sdk'

module RspecOtel
  def self.exporter
    @exporter ||= OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
  end
end

require 'rspec_otel/rspec'
require 'rspec_otel/version'
