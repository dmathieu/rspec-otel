# frozen_string_literal: true

require 'spec_helper'

describe RspecOtel do
  describe '#exporter' do
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
end
