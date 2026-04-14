# frozen_string_literal: true

require 'spec_helper'

describe RspecOtel do
  describe '.exporter' do
    subject { described_class.exporter }

    let(:exporter) { subject }

    it { is_expected.to be_a(OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter) }

    it 'is memoized' do
      expect(exporter).to equal(exporter)
    end

    it 'is reset' do
      expect(exporter.finished_spans).to be_empty
    end
  end

  describe '.record', :rspec_otel_disable_tracing do
    it "doesn't leak spans across subsequent calls" do
      described_class.record do
        OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('first').finish
        expect(described_class.exporter.finished_spans.map(&:name)).to eq(['first'])
        # Ensure that even when explicitly shutdown the subsequent call will continue to capture spans
        OpenTelemetry.tracer_provider.shutdown
      end

      described_class.record do
        OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('second').finish
        expect(described_class.exporter.finished_spans.map(&:name)).to eq(['second'])
      end
    end

    it "doesn't leak metrics across subsequent calls" do
      described_class.record do
        meter = OpenTelemetry.meter_provider.meter('rspec-otel')
        meter.create_counter('first').add(1)
        described_class.metric_exporter.pull
        expect(described_class.metric_exporter.metric_snapshots.map(&:name)).to include('first')
      end

      described_class.record do
        described_class.metric_exporter.pull
        expect(described_class.metric_exporter.metric_snapshots.map(&:name)).not_to include('first')
      end
    end

    it "doesn't record unwrapped examples" do
      OpenTelemetry.tracer_provider.tracer('rspec-otel').in_span('test') do
        expect(OpenTelemetry::Trace.current_span).not_to be_recording
      end
    end

    it 'records wrapped examples' do
      described_class.record do
        expect(OpenTelemetry::Trace.current_span).not_to be_recording

        OpenTelemetry.tracer_provider.tracer('rspec-otel').in_span('test') do
          expect(OpenTelemetry::Trace.current_span).to be_recording
        end
      end
    end
  end
end
