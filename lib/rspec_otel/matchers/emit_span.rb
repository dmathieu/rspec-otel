# frozen_string_literal: true

module RspecOtel
  module Matchers
    class EmitSpan
      attr_reader :name

      def initialize(name = nil)
        @name = name
        @filters = []
        @before_spans = []
        @closest_span = nil

        @filters << name_filter
      end

      def matches?(block)
        capture_before_spans(block)
        matching_span?
      end

      def as_child
        @filters << ->(span) { span.parent_span_id && span.parent_span_id != OpenTelemetry::Trace::INVALID_SPAN_ID }
        self
      end

      def as_root
        @filters << ->(span) { span.parent_span_id == OpenTelemetry::Trace::INVALID_SPAN_ID }
        self
      end

      def with_attributes(attributes)
        @filters << ->(span) { attributes_match?(span.attributes, attributes) }
        self
      end

      def without_attributes(attributes)
        @filters << ->(span) { !attributes_match?(span.attributes, attributes) }
        self
      end

      def with_link(attributes = {})
        @filters << ->(span) { span.links && link_match?(span.links, attributes) }
        self
      end

      def without_link(attributes = {})
        @filters << ->(span) { span.links.nil? || !link_match?(span.links, attributes) }
        self
      end

      def with_event(name, attributes = {})
        event = OpenTelemetry::SDK::Trace::Event.new(name, attributes)
        @filters << ->(span) { span.events && event_match?(span.events, event) }
        self
      end

      def without_event(name, attributes = {})
        event = OpenTelemetry::SDK::Trace::Event.new(name, attributes)
        @filters << ->(span) { span.events.nil? || !event_match?(span.events, event) }
        self
      end

      def with_status(code, description)
        @filters << ->(span) { status_match?(span.status, code, description) }
        self
      end

      def with_exception(exception = nil)
        with_event('exception', exception_attributes(exception))
      end

      def without_exception(exception = nil)
        without_event('exception', exception_attributes(exception))
      end

      def failure_message
        closest = closest_span
        prefix = "expected span #{failure_match_description} #{printable_name} to have been emitted"

        case closest
        when nil then "#{prefix}, but there were no spans emitted at all"
        when OpenTelemetry::SDK::Trace::SpanData then closest_not_found_message(prefix, closest)
        else raise "I don't know what to do with a #{closest.class} span"
        end
      end

      def failure_message_when_negated
        "expected span #{failure_match_description} #{printable_name} to not have been emitted"
      end

      def supports_block_expectations?
        true
      end

      private

      def capture_before_spans(block)
        return unless block.respond_to?(:call)

        @before_spans = RspecOtel.exporter.finished_spans
        block.call
      end

      def matching_span?
        closest_count = 0
        (RspecOtel.exporter.finished_spans - @before_spans).each do |span|
          count = @filters.count { |f| f.call(span) }
          @closest_span = span if count > closest_count
          closest_count = count
          return true if count == @filters.count
        end
        false
      end

      def closest_span
        return @closest_span unless @closest_span.nil?

        (RspecOtel.exporter.finished_spans - @before_spans).first
      end

      def failure_match_description
        case name
        when String
          'named'
        when Regexp
          'matching'
        end
      end

      def printable_name
        case name
        when String
          "'#{name}'"
        when Regexp
          name.inspect
        end
      end

      def name_filter
        lambda do |span|
          case name
          when String
            span.name == name
          when Regexp
            span.name.match?(name)
          end
        end
      end

      def exception_attributes(exception)
        attributes = {}
        return attributes if exception.nil?

        if exception.is_a?(Exception)
          attributes['exception.type'] = exception.class.to_s
          attributes['exception.message'] = exception.message
        else
          attributes['exception.type'] = exception.to_s
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

      def closest_not_found_message(prefix, span)
        "#{prefix}, but it couldn't be found. " \
          "Found a close matching span named `#{span.name}`#{SpanDetails.new(span)}"
      end
    end
  end
end
