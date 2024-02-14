# frozen_string_literal: true

require 'spec_helper'

describe RspecOtel::Matchers::EmitSpan do
  it 'has not emitted a span' do
    expect do
      # Do nothing
    end.not_to emit_span('test')
  end

  it 'has emitted a span' do
    expect do
      span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test')
      span.finish
    end.to emit_span('test')
  end

  it 'has emitted a span from a different name' do
    expect do
      span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('testing')
      span.finish
    end.not_to emit_span('test')
  end

  it 'only looks for spans emitted within the block' do
    span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test')
    span.finish
    expect do
      # Do nothing in here
    end.not_to emit_span('test')
  end

  describe 'without a block' do
    before do
      span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test')
      span.finish
    end

    it { is_expected.to emit_span('test') }
    it { is_expected.not_to emit_span('testing') }
  end

  describe 'with_attributes' do
    it 'matches a span with its attributes' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel')
                            .start_span('test', attributes: {
                                          'hello' => 'world'
                                        })
        span.finish
      end.to emit_span('test').with_attributes({ 'hello' => 'world' })
    end

    it 'matches a span with some unspecified attributes' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel')
                            .start_span('test', attributes: {
                                          'hello' => 'world',
                                          'holla' => 'mundo'
                                        })
        span.finish
      end.to emit_span('test').with_attributes({ 'hello' => 'world' })
    end

    it 'does not match a span with wrong attributes' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel')
                            .start_span('test', attributes: {
                                          'hello' => 'monde'
                                        })
        span.finish
      end.not_to emit_span('test').with_attributes({ 'hello' => 'world' })
    end
  end

  describe 'without_attributes' do
    it 'matches a span without a specified attribute' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel')
                            .start_span('test', attributes: {
                                          'hello' => 'mundo'
                                        })
        span.finish
      end.to emit_span('test').without_attributes({ 'hello' => 'world' })
    end

    it 'does not match a span with the restricted attributes' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel')
                            .start_span('test', attributes: {
                                          'hello' => 'world'
                                        })
        span.finish
      end.not_to emit_span('test').without_attributes({ 'hello' => 'world' })
    end
  end

  describe 'with_status' do
    it 'matches a span with its status' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test')
        span.status = OpenTelemetry::Trace::Status.error('an error occured')
        span.finish
      end.to emit_span('test').with_status(OpenTelemetry::Trace::Status::ERROR, 'an error occured')
    end

    it 'does not match a span with a wrong status' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test')
        span.status = OpenTelemetry::Trace::Status.error('an error occured')
        span.finish
      end.not_to emit_span('test').with_status(OpenTelemetry::Trace::Status::OK, '')
    end
  end

  describe 'with_events' do
    it 'matches a span with events' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test')
        span.add_event('testing an event')
        span.finish
      end.to emit_span('test').with_event('testing an event')
    end

    it 'matches a span with some unspecified events' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test')
        span.add_event('testing an event')
        span.add_event('and a second one')
        span.finish
      end.to emit_span('test').with_event('testing an event')
    end

    it 'does not match a span with wrong events' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test')
        span.add_event('testing an event')
        span.finish
      end.not_to emit_span('test').with_event('a second event')
    end
  end

  describe 'without_events' do
    it 'matches a span without a specified event' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test')
        span.add_event('testing an event')
        span.finish
      end.to emit_span('test').without_event('testing')
    end

    it 'does not match a span with the restricted event' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test')
        span.add_event('testing an event')
        span.finish
      end.not_to emit_span('test').without_event('testing an event')
    end
  end

  describe 'with exception' do
    it 'matches a span with its exception' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test')
        span.record_exception(StandardError.new('some error occured'))
        span.finish
      end.to emit_span('test').with_exception(StandardError.new('some error occured'))
    end

    it 'matches a span with any exception' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test')
        span.record_exception(StandardError.new('some error occured'))
        span.finish
      end.to emit_span('test').with_exception
    end

    it 'does not match a span with a wrong exception' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test')
        span.record_exception(StandardError.new('some error occured'))
        span.finish
      end.not_to emit_span('test').with_exception(StandardError.new('an error'))
    end
  end

  describe 'without exception' do
    it 'matches a span without the specified exception' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test')
        span.record_exception(StandardError.new('some error occured'))
        span.finish
      end.to emit_span('test').without_exception(StandardError.new('error'))
    end

    it 'matches a span with no exception at all' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test')
        span.record_exception(StandardError.new('some error occured'))
        span.finish
      end.not_to emit_span('test').without_exception
    end

    it 'does not match a span with the exception' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test')
        span.record_exception(StandardError.new('some error occured'))
        span.finish
      end.not_to emit_span('test').without_exception(StandardError.new('some error occured'))
    end
  end
end
