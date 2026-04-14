# frozen_string_literal: true

module RspecOtel
  module Matchers
    def emit_span(name)
      EmitSpan.new(name)
    end

    def emit_metric(name)
      EmitMetric.new(name)
    end
  end
end

require 'rspec_otel/matchers/emit_span'
require 'rspec_otel/matchers/emit_metric'
require 'rspec_otel/matchers/span_details'
require 'rspec_otel/matchers/metric_details'
