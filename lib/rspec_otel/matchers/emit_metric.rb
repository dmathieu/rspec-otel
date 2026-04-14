# frozen_string_literal: true

module RspecOtel
  module Matchers
    class EmitMetric
      def initialize(name)
        @name = name
        @kind = nil
        @filters = []
        @before_count = 0
        @pre_snapshot = {}
        @closest_metric = nil
        @closest_filter_count = 0
        @emitted_outside_block = false
      end

      def matches?(block)
        execute_block(block) if block.respond_to?(:call)
        matching_metric?
      end

      def of_type(kind)
        @kind = kind
        self
      end

      def with_attributes(attributes)
        @filters << ->(dp) { attributes_match?(dp.attributes || {}, attributes) }
        self
      end

      def without_attributes(attributes)
        @filters << ->(dp) { !attributes_match?(dp.attributes || {}, attributes) }
        self
      end

      def with_value(value)
        @filters << lambda { |dp|
          raise ArgumentError, 'with_value is not supported for histogram data points' unless dp.respond_to?(:value)

          dp.value == value
        }
        self
      end

      def failure_message
        closest = @closest_metric || new_snapshots.first
        if closest.nil?
          "expected metric #{printable_name} to have been emitted, but no metrics were emitted at all"
        elsif @emitted_outside_block
          "expected metric #{printable_name} to have been emitted within the block, but it was already emitted before"
        else
          "expected metric #{printable_name} to have been emitted, but it couldn't be found. " \
            "Found a close matching metric named `#{closest.name}`#{MetricDetails.new(closest)}"
        end
      end

      def failure_message_when_negated
        "expected metric #{printable_name} to not have been emitted"
      end

      def supports_block_expectations?
        true
      end

      private

      def execute_block(block)
        RspecOtel.metric_exporter.pull
        @pre_snapshot = build_pre_snapshot(RspecOtel.metric_exporter.metric_snapshots)
        @before_count = RspecOtel.metric_exporter.metric_snapshots.length
        block.call
        RspecOtel.metric_exporter.pull
      end

      def matching_metric?
        new_snapshots.each do |metric_data|
          next unless name_matches?(metric_data.name)
          next unless kind_matches?(metric_data.instrument_kind)

          return true if matching_data_point?(metric_data)

          @closest_metric ||= metric_data
        end

        false
      end

      def matching_data_point?(metric_data)
        any_changed = false
        metric_data.data_points.each do |data_point|
          next unless data_point_changed?(metric_data.name, metric_data.instrument_kind, data_point)

          any_changed = true
          return true if all_filters_match?(metric_data, data_point)
        end
        @emitted_outside_block ||= !any_changed
        false
      end

      def all_filters_match?(metric_data, data_point)
        count = @filters.count { |f| f.call(data_point) }
        if count > @closest_filter_count
          @closest_metric = metric_data
          @closest_filter_count = count
        end
        count == @filters.length
      end

      def data_point_changed?(metric_name, instrument_kind, data_point)
        pre = @pre_snapshot.dig(metric_name, data_point.attributes)
        return true if pre.nil?
        return false if observable_instrument?(instrument_kind)

        pre != data_point_magnitude(data_point)
      end

      def observable_instrument?(instrument_kind)
        %i[observable_counter observable_gauge observable_up_down_counter].include?(instrument_kind)
      end

      def data_point_magnitude(data_point)
        data_point.respond_to?(:value) ? data_point.value : data_point.count
      end

      def build_pre_snapshot(snapshots)
        # metric_snapshots accumulates across pulls; if the same metric name appears multiple
        # times, to_h keeps the last entry — which is the most recent (and correct) baseline.
        snapshots.to_h do |metric_data|
          [metric_data.name, metric_data.data_points.to_h { |dp| [dp.attributes, data_point_magnitude(dp)] }]
        end
      end

      def new_snapshots
        RspecOtel.metric_exporter.metric_snapshots[@before_count..]
      end

      def kind_matches?(instrument_kind)
        @kind.nil? || instrument_kind == @kind
      end

      def name_matches?(metric_name)
        case @name
        when String then metric_name == @name
        when Regexp then metric_name.match?(@name)
        end
      end

      def printable_name
        case @name
        when String then "'#{@name}'"
        when Regexp then @name.inspect
        end
      end

      def attributes_match?(actual, expected)
        expected.all? { |k, v| actual[k] == v }
      end
    end
  end
end
