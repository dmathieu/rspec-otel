# frozen_string_literal: true

module RspecOtel
  module Matchers
    class SpanDetails
      def initialize(span)
        @span = span
      end

      def to_s
        lines = [attributes_details, events_details, links_details, status_details].compact
        return '' if lines.empty?

        "\n#{lines.join("\n")}"
      end

      private

      def attributes_details
        return unless @span.attributes&.any?

        "  attributes: #{@span.attributes.inspect}"
      end

      def events_details
        return unless @span.events&.any?

        format_collection('events', @span.events) { |e| format_item(e.name, e.attributes) }
      end

      def links_details
        return unless @span.links&.any?

        format_collection('links', @span.links) { |l| format_item('link', l.attributes) }
      end

      def status_details
        return if @span.status.nil? || @span.status.code == OpenTelemetry::Trace::Status::UNSET

        label = status_label(@span.status.code)
        desc = @span.status.description
        status_str = desc.to_s.empty? ? label : "#{label} (#{desc})"
        "  status: #{status_str}"
      end

      def format_collection(header, collection, &)
        item_lines = collection.map(&)
        "  #{header}:\n#{item_lines.join("\n")}"
      end

      def format_item(label, attributes)
        attributes&.any? ? "    - #{label} #{attributes.inspect}" : "    - #{label}"
      end

      def status_label(code)
        case code
        when OpenTelemetry::Trace::Status::OK    then 'ok'
        when OpenTelemetry::Trace::Status::ERROR then 'error'
        else 'unknown'
        end
      end
    end
  end
end
