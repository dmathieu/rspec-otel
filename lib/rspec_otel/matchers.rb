# frozen_string_literal: true

module RspecOtel
  module Matchers
    def have_emitted_span(name) # rubocop:disable Naming/PredicateName
      HaveEmittedSpan.new(name)
    end
  end
end

require 'rspec_otel/matchers/have_emitted_span'
