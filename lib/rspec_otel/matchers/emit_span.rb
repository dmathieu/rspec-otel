# frozen_string_literal: true

module RspecOtel
  module Matchers
    class EmitSpan # rubocop:disable Metrics/ClassLength
      attr_reader :name

      def initialize(name = nil)
        @name = name
        @filters = [
          ->(span) { span.name == name }
        ]
      end

      def matches?(block)
        before_spans = []
        if block.respond_to?(:call)
          before_spans = RspecOtel.exporter.finished_spans
          block.call
        end

        (RspecOtel.exporter.finished_spans - before_spans).each do |span|
          return true if @filters.all? { |f| f.call(span) }
        end

        false
      end

      def as_child
        @filters << lambda do |span|
          span.parent_span_id && span.parent_span_id != OpenTelemetry::Trace::INVALID_SPAN_ID
        end

        self
      end

      def as_root
        @filters << lambda do |span|
          span.parent_span_id == OpenTelemetry::Trace::INVALID_SPAN_ID
        end

        self
      end

      def with_attributes(*attributes)
        @filters << lambda do |span|
          RSpec::Matchers::BuiltIn::Include.new(*attributes).matches?(span.attributes)
        end

        self
      end

      def without_attributes(*attributes)
        @filters << lambda do |span|
          !RSpec::Matchers::BuiltIn::Include.new(*attributes).matches?(span.attributes)
        end

        self
      end

      def with_link(attributes = {})
        @filters << lambda do |span|
          span.links &&
            link_match?(span.links, attributes)
        end

        self
      end

      def without_link(attributes = {})
        @filters << lambda do |span|
          span.links.nil? ||
            !link_match?(span.links, attributes)
        end

        self
      end

      def with_event(name, attributes = {})
        @filters << lambda do |span|
          span.events &&
            event_match?(span.events, OpenTelemetry::SDK::Trace::Event.new(name, attributes))
        end

        self
      end

      def without_event(name, attributes = {})
        @filters << lambda do |span|
          span.events.nil? ||
            !event_match?(span.events, OpenTelemetry::SDK::Trace::Event.new(name, attributes))
        end

        self
      end

      def with_status(code, description)
        @filters << lambda do |span|
          status_match?(span.status, code, description)
        end
        self
      end

      def with_exception(exception = nil)
        with_event('exception', exception_attributes(exception))
      end

      def without_exception(exception = nil)
        without_event('exception', exception_attributes(exception))
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

      def exception_attributes(exception)
        attributes = {}
        unless exception.nil?
          attributes['exception.type'] = exception.class.to_s
          attributes['exception.message'] = exception.message
        end

        attributes
      end

      def attributes_match?(span_attributes, attributes)
        attributes.each do |ak, av|
          sa = span_attributes.select do |k, v|
            ak == k && av == v
          end

          return false if sa.empty?
        end

        true
      end

      def status_match?(span_status, code, description)
        code == span_status.code && description == span_status.description
      end

      def event_match?(span_events, event)
        se = span_events.select do |s|
          s.name == event.name &&
            attributes_match?(s.attributes, event.attributes || {})
        end

        !se.empty?
      end

      def link_match?(links, attributes)
        link = links.select do |l|
          attributes_match?(l.attributes, attributes || {})
        end

        !link.empty?
      end
    end
  end
end
