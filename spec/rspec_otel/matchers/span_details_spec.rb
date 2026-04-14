# frozen_string_literal: true

require 'spec_helper'

describe RspecOtel::Matchers::SpanDetails do
  def build_span(name, attributes: nil, events: [], links: nil, status: nil)
    span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span(name, attributes: attributes, links: links)
    events.each { |e| span.add_event(e[:name], attributes: e[:attributes]) }
    span.status = status if status
    span.finish
    RspecOtel.exporter.finished_spans.last
  end

  subject(:details) { described_class.new(span).to_s }

  context 'with no attributes, events, links, or non-default status' do
    let(:span) { build_span('test') }

    it { is_expected.to eq('') }
  end

  context 'with attributes' do
    let(:span) { build_span('test', attributes: { 'hello' => 'world' }) }

    it { is_expected.to eq("\n  attributes: {\"hello\" => \"world\"}") }
  end

  context 'with an event without attributes' do
    let(:span) { build_span('test', events: [{ name: 'something happened', attributes: nil }]) }

    it { is_expected.to eq("\n  events:\n    - something happened") }
  end

  context 'with an event with attributes' do
    let(:span) { build_span('test', events: [{ name: 'something happened', attributes: { 'key' => 'value' } }]) }

    it { is_expected.to eq("\n  events:\n    - something happened {\"key\" => \"value\"}") }
  end

  context 'with multiple events' do
    let(:span) do
      build_span('test', events: [
                   { name: 'first', attributes: nil },
                   { name: 'second', attributes: { 'k' => 'v' } }
                 ])
    end

    it { is_expected.to eq("\n  events:\n    - first\n    - second {\"k\" => \"v\"}") }
  end

  context 'with a link without attributes' do
    let(:span) do
      parent = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('parent')
      link = OpenTelemetry::Trace::Link.new(parent.context)
      s = build_span('test', links: [link])
      parent.finish
      s
    end

    it { is_expected.to eq("\n  links:\n    - link") }
  end

  context 'with a link with attributes' do
    let(:span) do
      parent = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('parent')
      link = OpenTelemetry::Trace::Link.new(parent.context, { 'foo' => 'bar' })
      s = build_span('test', links: [link])
      parent.finish
      s
    end

    it { is_expected.to eq("\n  links:\n    - link {\"foo\" => \"bar\"}") }
  end

  context 'with multiple links' do
    let(:span) do
      p1 = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('parent1')
      p2 = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('parent2')
      links = [
        OpenTelemetry::Trace::Link.new(p1.context),
        OpenTelemetry::Trace::Link.new(p2.context, { 'k' => 'v' })
      ]
      s = build_span('test', links: links)
      p1.finish
      p2.finish
      s
    end

    it { is_expected.to eq("\n  links:\n    - link\n    - link {\"k\" => \"v\"}") }
  end

  context 'with error status with description' do
    let(:span) { build_span('test', status: OpenTelemetry::Trace::Status.error('went wrong')) }

    it { is_expected.to eq("\n  status: error (went wrong)") }
  end

  context 'with error status without description' do
    let(:span) { build_span('test', status: OpenTelemetry::Trace::Status.error('')) }

    it { is_expected.to eq("\n  status: error") }
  end

  context 'with ok status' do
    let(:span) { build_span('test', status: OpenTelemetry::Trace::Status.ok) }

    it { is_expected.to eq("\n  status: ok") }
  end

  context 'with attributes, events, and status' do
    let(:span) do
      build_span('test',
        attributes: { 'hello' => 'world' },
        events: [{ name: 'something happened', attributes: nil }],
        status: OpenTelemetry::Trace::Status.error('oops'))
    end

    it do
      expected = "\n  attributes: {\"hello\" => \"world\"}\n  events:\n    - something happened\n  status: error (oops)"
      expect(details).to eq(expected)
    end
  end
end
