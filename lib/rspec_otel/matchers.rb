# frozen_string_literal: true

module RspecOtel
  module Matchers
    def emit_span(name)
      EmitSpan.new(name)
    end
  end
end

require 'rspec_otel/matchers/emit_span'
