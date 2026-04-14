# frozen_string_literal: true

module RspecOtel
  module Matchers
    class MetricDetails
      def initialize(metric)
        @metric = metric
      end

      def to_s
        "\n#{[type_details, data_points_details].compact.join("\n")}"
      end

      private

      def type_details
        "  type: #{@metric.instrument_kind}"
      end

      def data_points_details
        return unless @metric.data_points&.any?

        format_collection('data_points', @metric.data_points) { |dp| format_data_point(dp) }
      end

      def format_collection(header, collection, &)
        item_lines = collection.map(&)
        "  #{header}:\n#{item_lines.join("\n")}"
      end

      def format_data_point(data_point)
        magnitude_label = data_point.respond_to?(:value) ? "value: #{data_point.value}" : "count: #{data_point.count}"
        attrs = data_point.attributes
        attrs&.any? ? "    - #{magnitude_label} #{attrs.inspect}" : "    - #{magnitude_label}"
      end
    end
  end
end
