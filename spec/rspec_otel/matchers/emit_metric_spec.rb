# frozen_string_literal: true

require 'spec_helper'

describe RspecOtel::Matchers::EmitMetric do
  let(:meter) { OpenTelemetry.meter_provider.meter('rspec-otel') }

  shared_examples 'a metric' do
    it 'has emitted a metric' do
      expect { record_metric.call }.to emit_metric(metric_name)
    end

    it 'only looks for metrics emitted within the block' do
      record_metric.call
      expect do
        # Nothing to do here
      end.not_to emit_metric(metric_name)
    end
  end

  context 'with a counter' do
    let(:metric_name) { 'my.counter' }
    let(:record_metric) { -> { meter.create_counter('my.counter').add(1) } }

    it_behaves_like 'a metric'
  end

  context 'with a histogram' do
    let(:metric_name) { 'my.histogram' }
    let(:record_metric) { -> { meter.create_histogram('my.histogram').record(42) } }

    it_behaves_like 'a metric'
  end

  context 'with a gauge' do
    let(:metric_name) { 'my.gauge' }
    let(:record_metric) { -> { meter.create_gauge('my.gauge').record(1) } }

    it_behaves_like 'a metric'
  end

  context 'with an up_down_counter' do
    let(:metric_name) { 'my.up_down_counter' }
    let(:record_metric) { -> { meter.create_up_down_counter('my.up_down_counter').add(1) } }

    it_behaves_like 'a metric'
  end

  context 'with an observable_counter' do
    let(:metric_name) { 'my.observable_counter' }
    let(:record_metric) { -> { meter.create_observable_counter('my.observable_counter', callback: proc { 1 }) } }

    it_behaves_like 'a metric'
  end

  context 'with an observable_gauge' do
    let(:metric_name) { 'my.observable_gauge' }
    let(:record_metric) { -> { meter.create_observable_gauge('my.observable_gauge', callback: proc { 1 }) } }

    it_behaves_like 'a metric'
  end

  context 'with an observable_up_down_counter' do
    let(:metric_name) { 'my.observable_up_down_counter' }
    let(:record_metric) do
      -> { meter.create_observable_up_down_counter('my.observable_up_down_counter', callback: proc { 1 }) }
    end

    it 'has emitted a metric' do
      expect { record_metric.call }.to emit_metric(metric_name)
    end

    # The SDK hardcodes cumulative Sum for this instrument kind, so the aggregated
    # value grows on every pull (1, 2, 3, ...). That makes pre/post comparison
    # unreliable for the isolation check regardless of temporality env settings.
    it 'only looks for metrics emitted within the block' do
      skip 'observable_up_down_counter hardcodes cumulative Sum, causing the value to ' \
           'grow on every pull regardless of OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE'
    end
  end

  it 'has emitted a metric with a different name' do
    expect do
      meter.create_counter('other.counter').add(1)
    end.not_to emit_metric('my.counter')
  end

  it 'has printed a sensible error message when no metrics emitted' do
    matcher = emit_metric('my.counter')
    matcher.matches?(-> {})
    expect(matcher.failure_message).to eq(
      "expected metric 'my.counter' to have been emitted, but no metrics were emitted at all"
    )
  end

  it 'has printed a sensible error message when metric was emitted before the block' do
    # Observable metrics always report on every pull (cumulative), so they appear
    # in new_snapshots after the block with the same value → triggers @emitted_outside_block
    meter.create_observable_counter('my.observable_counter', callback: proc { 1 })
    matcher = emit_metric('my.observable_counter')
    matcher.matches?(-> {})
    expect(matcher.failure_message).to eq(
      "expected metric 'my.observable_counter' to have been emitted within the block, but it was already emitted before"
    )
  end

  it 'has printed a sensible error message when metric emitted with wrong value' do
    matcher = emit_metric('my.counter').with_value(5)
    matcher.matches?(-> { meter.create_counter('my.counter').add(3) })
    expect(matcher.failure_message).to eq(
      "expected metric 'my.counter' to have been emitted, but it couldn't be found. " \
      "Found a close matching metric named `my.counter`\n  type: counter\n  data_points:\n    - value: 3"
    )
  end

  it 'has printed a sensible error message when wrong metric emitted' do
    matcher = emit_metric('my.counter')
    matcher.matches?(-> { meter.create_counter('other.counter').add(1) })
    expect(matcher.failure_message).to eq(
      "expected metric 'my.counter' to have been emitted, but it couldn't be found. " \
      "Found a close matching metric named `other.counter`\n  type: counter\n  data_points:\n    - value: 1"
    )
  end

  it 'has printed a sensible error message when the closest metric has attributes' do
    matcher = emit_metric('my.counter').with_attributes({ 'env' => 'test' })
    matcher.matches?(-> { meter.create_counter('my.counter').add(2, attributes: { 'env' => 'production' }) })
    expect(matcher.failure_message).to eq(
      "expected metric 'my.counter' to have been emitted, but it couldn't be found. " \
      'Found a close matching metric named `my.counter`' \
      "\n  type: counter\n  data_points:\n    - value: 2 {\"env\" => \"production\"}"
    )
  end

  it 'has printed a sensible error message when the closest metric is a histogram' do
    matcher = emit_metric('my.histogram').with_attributes({ 'env' => 'test' })
    matcher.matches?(-> { meter.create_histogram('my.histogram').record(42) })
    expect(matcher.failure_message).to eq(
      "expected metric 'my.histogram' to have been emitted, but it couldn't be found. " \
      "Found a close matching metric named `my.histogram`\n  type: histogram\n  data_points:\n    - count: 1"
    )
  end

  context 'when using a regular expression' do
    it 'has emitted a metric with a matching name' do
      expect do
        meter.create_counter('http.server.requests').add(1)
      end.to emit_metric(/^http\./)
    end

    it 'has emitted a metric without a matching name' do
      expect do
        meter.create_counter('db.queries').add(1)
      end.not_to emit_metric(/^http\./)
    end

    it 'has printed a sensible error message when no metrics emitted' do
      matcher = emit_metric(/^http\./)
      matcher.matches?(-> {})
      expect(matcher.failure_message).to eq(
        'expected metric /^http\\./ to have been emitted, but no metrics were emitted at all'
      )
    end

    it 'has printed a sensible error message when a close metric is found' do
      matcher = emit_metric(/^http\./)
      matcher.matches?(-> { meter.create_counter('db.queries').add(1) })
      expect(matcher.failure_message).to eq(
        "expected metric /^http\\./ to have been emitted, but it couldn't be found. " \
        "Found a close matching metric named `db.queries`\n  type: counter\n  data_points:\n    - value: 1"
      )
    end
  end

  context 'with attributes' do
    it 'matches when attributes are present' do
      expect do
        meter.create_counter('my.counter').add(1, attributes: { 'env' => 'test' })
      end.to emit_metric('my.counter').with_attributes({ 'env' => 'test' })
    end

    it 'does not match when attributes differ' do
      expect do
        meter.create_counter('my.counter').add(1, attributes: { 'env' => 'production' })
      end.not_to emit_metric('my.counter').with_attributes({ 'env' => 'test' })
    end

    it 'supports partial attribute matching' do
      expect do
        meter.create_counter('my.counter').add(1, attributes: { 'env' => 'test', 'region' => 'us-east-1' })
      end.to emit_metric('my.counter').with_attributes({ 'env' => 'test' })
    end
  end

  context 'with without_attributes' do
    it 'matches when the attributes are absent' do
      expect do
        meter.create_counter('my.counter').add(1)
      end.to emit_metric('my.counter').without_attributes({ 'env' => 'test' })
    end

    it 'does not match when the attributes are present' do
      expect do
        meter.create_counter('my.counter').add(1, attributes: { 'env' => 'test' })
      end.not_to emit_metric('my.counter').without_attributes({ 'env' => 'test' })
    end
  end

  context 'with value' do
    it 'matches when the value is correct' do
      expect do
        meter.create_counter('my.counter').add(5)
      end.to emit_metric('my.counter').with_value(5)
    end

    it 'does not match when the value differs' do
      expect do
        meter.create_counter('my.counter').add(3)
      end.not_to emit_metric('my.counter').with_value(5)
    end

    it 'raises ArgumentError when used on a histogram' do
      matcher = emit_metric('my.histogram').with_value(42)
      expect { matcher.matches?(-> { meter.create_histogram('my.histogram').record(42) }) }
        .to raise_error(ArgumentError, 'with_value is not supported for histogram data points')
    end
  end

  context 'when combining matchers' do
    it 'matches when both attributes and value are correct' do
      expect do
        meter.create_counter('my.counter').add(2, attributes: { 'env' => 'test' })
      end.to emit_metric('my.counter').with_attributes({ 'env' => 'test' }).with_value(2)
    end

    it 'does not match when value is wrong even if attributes match' do
      expect do
        meter.create_counter('my.counter').add(1, attributes: { 'env' => 'test' })
      end.not_to emit_metric('my.counter').with_attributes({ 'env' => 'test' }).with_value(99)
    end
  end

  context 'with of_type' do
    it 'matches when the instrument kind is correct' do
      expect do
        meter.create_counter('my.counter').add(1)
      end.to emit_metric('my.counter').of_type(:counter)
    end

    it 'does not match when the instrument kind differs' do
      expect do
        meter.create_counter('my.counter').add(1)
      end.not_to emit_metric('my.counter').of_type(:histogram)
    end

    it 'matches a histogram' do
      expect do
        meter.create_histogram('my.histogram').record(42)
      end.to emit_metric('my.histogram').of_type(:histogram)
    end
  end

  context 'when negated' do
    it 'has printed a sensible error message' do
      matcher = emit_metric('my.counter')
      matcher.matches?(-> { meter.create_counter('my.counter').add(1) })
      expect(matcher.failure_message_when_negated).to eq("expected metric 'my.counter' to not have been emitted")
    end
  end
end
