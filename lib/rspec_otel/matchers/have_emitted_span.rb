# frozen_string_literal: true

module RspecOtel
  module Matchers
    class HaveEmittedSpan
      attr_reader :name

      def initialize(name)
        @name = name
        @attributes = {}
      end

      def matches?(block)
        block.call if block.respond_to?(:call)

        RspecOtel.exporter.finished_spans.each do |span|
          return true if span.name == name &&
                         attributes_match?(span.attributes, @attributes) &&
                         status_match?(span.status, @status) &&
                         events_match?(span.events, @events)
        end

        false
      end

      def with_attributes(attributes)
        @attributes = attributes
        self
      end

      def with_event(name, attributes = {})
        @events ||= []
        @events << OpenTelemetry::SDK::Trace::Event.new(name, attributes)
        self
      end

      def with_status(code, description)
        @status = { code:, description: }
        self
      end

      def with_exception(exception)
        with_event('exception', {
                     'exception.type' => exception.class.to_s,
                     'exception.message' => exception.message
                   })
      end

      def failure_message
        "expected span #{name} to have been emitted, but it couldn't be found"
      end

      def failure_message_when_negated
        "expected span #{name} to not have been emitted"
      end

      def supports_block_expectations?
        true
      end

      private

      def attributes_match?(span_attributes, attributes)
        attributes.each do |ak, av|
          sa = span_attributes.select do |k, v|
            ak == k && av == v
          end

          return false if sa.empty?
        end

        true
      end

      def status_match?(span_status, status)
        status.nil? ||
          (status[:code] == span_status.code && status[:description] == span_status.description)
      end

      def events_match?(span_events, events)
        return true if span_events.nil?

        events.each do |e|
          se = span_events.select do |s|
            s.name == e.name &&
              attributes_match?(s.attributes, e.attributes)
          end

          return false if se.empty?
        end

        true
      end
    end
  end
end
