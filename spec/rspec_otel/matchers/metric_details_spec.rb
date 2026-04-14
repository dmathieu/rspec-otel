# frozen_string_literal: true

require 'spec_helper'

describe RspecOtel::Matchers::MetricDetails do
  subject(:details) { described_class.new(metric).to_s }

  let(:meter) { OpenTelemetry.meter_provider.meter('rspec-otel') }

  def build_counter(name, value, attributes: nil)
    meter.create_counter(name).add(value, **(attributes ? { attributes: attributes } : {}))
    pull_metric(name)
  end

  def build_histogram(name, value, attributes: nil)
    meter.create_histogram(name).record(value, **(attributes ? { attributes: attributes } : {}))
    pull_metric(name)
  end

  def pull_metric(name)
    RspecOtel.metric_exporter.pull
    RspecOtel.metric_exporter.metric_snapshots.find { |s| s.name == name }
  end

  context 'with a counter and no data points' do
    let(:metric) { Struct.new(:instrument_kind, :data_points).new(:counter, []) }

    it { is_expected.to eq("\n  type: counter") }
  end

  context 'with a counter and nil data points' do
    let(:metric) { Struct.new(:instrument_kind, :data_points).new(:counter, nil) }

    it { is_expected.to eq("\n  type: counter") }
  end

  context 'with a counter with a single data point and no attributes' do
    let(:metric) { build_counter('my.counter', 5) }

    it { is_expected.to eq("\n  type: counter\n  data_points:\n    - value: 5") }
  end

  context 'with a counter with a single data point and attributes' do
    let(:metric) { build_counter('my.counter', 3, attributes: { 'env' => 'test' }) }

    it { is_expected.to eq("\n  type: counter\n  data_points:\n    - value: 3 {\"env\" => \"test\"}") }
  end

  context 'with a counter with multiple data points' do
    let(:metric) do
      counter = meter.create_counter('my.counter')
      counter.add(5)
      counter.add(3, attributes: { 'env' => 'test' })
      pull_metric('my.counter')
    end

    it { is_expected.to include('  type: counter') }
    it { is_expected.to include('    - value: 5') }
    it { is_expected.to include('    - value: 3 {"env" => "test"}') }
  end

  context 'with a histogram data point' do
    let(:metric) { build_histogram('my.histogram', 42) }

    it { is_expected.to eq("\n  type: histogram\n  data_points:\n    - count: 1") }
  end

  context 'with a histogram data point and attributes' do
    let(:metric) { build_histogram('my.histogram', 10, attributes: { 'region' => 'us-east-1' }) }

    it { is_expected.to eq("\n  type: histogram\n  data_points:\n    - count: 1 {\"region\" => \"us-east-1\"}") }
  end

  context 'with a gauge' do
    let(:metric) do
      meter.create_gauge('my.gauge').record(7, attributes: { 'host' => 'web-01' })
      pull_metric('my.gauge')
    end

    it { is_expected.to eq("\n  type: gauge\n  data_points:\n    - value: 7 {\"host\" => \"web-01\"}") }
  end

  context 'with an up_down_counter' do
    let(:metric) do
      meter.create_up_down_counter('my.udc').add(10)
      pull_metric('my.udc')
    end

    it { is_expected.to eq("\n  type: up_down_counter\n  data_points:\n    - value: 10") }
  end
end
