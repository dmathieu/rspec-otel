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

  it 'only looks for spans emitted within the block' do
    span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test')
    span.finish
    expect do
      # Do nothing in here
    end.not_to emit_span('test')
  end

  it 'has emitted a span from a different name' do
    expect do
      span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('testing')
      span.finish
    end.not_to emit_span('test')
  end

  it 'has printed a sensible error message' do
    OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('POST /user').finish
    matcher = emit_span('GET ')
    matcher.matches?(nil)
    expect(matcher.failure_message).to eq(
      "expected span named 'GET ' to have been emitted, but it couldn't be found. " \
      'Found a close matching span named `POST /user`'
    )
  end

  context 'when using a regular expression' do
    it 'has emitted a span with a matching name' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('GET /user')
        span.finish
      end.to emit_span(/^GET /)
    end

    it 'has emitted a span without a matching name' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('POST /user')
        span.finish
      end.not_to emit_span(/^GET /)
    end

    it 'has printed a sensible error message' do
      OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('POST /user').finish
      matcher = emit_span(/^GET /)
      matcher.matches?(nil)
      expect(matcher.failure_message).to eq(
        "expected span matching /^GET / to have been emitted, but it couldn't be found. " \
        'Found a close matching span named `POST /user`'
      )
    end
  end

  context 'when no span were emitted' do
    it 'has printed a sensible error message' do
      matcher = emit_span(/^GET /)
      matcher.matches?(nil)
      expect(matcher.failure_message).to eq(
        'expected span matching /^GET / to have been emitted, but there were no spans emitted at all'
      )
    end
  end

  context 'when printing details of a close matching span' do
    it 'includes attributes in the failure message' do
      OpenTelemetry.tracer_provider.tracer('rspec-otel')
                   .start_span('POST /user', attributes: { 'hello' => 'world' }).finish
      matcher = emit_span('GET ')
      matcher.matches?(nil)
      expect(matcher.failure_message).to eq(
        "expected span named 'GET ' to have been emitted, but it couldn't be found. " \
        "Found a close matching span named `POST /user`\n  attributes: {\"hello\" => \"world\"}"
      )
    end

    it 'includes events without attributes in the failure message' do
      span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('POST /user')
      span.add_event('something happened')
      span.finish
      matcher = emit_span('GET ')
      matcher.matches?(nil)
      expect(matcher.failure_message).to include("events:\n    - something happened")
    end

    it 'includes events with attributes in the failure message' do
      span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('POST /user')
      span.add_event('something happened', attributes: { 'key' => 'value' })
      span.finish
      matcher = emit_span('GET ')
      matcher.matches?(nil)
      expect(matcher.failure_message).to include('- something happened {"key" => "value"}')
    end

    it 'includes links in the failure message' do
      parent = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('parent')
      link = OpenTelemetry::Trace::Link.new(parent.context, { 'foo' => 'bar' })
      OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('POST /user', links: [link]).finish
      parent.finish
      matcher = emit_span('GET ')
      matcher.matches?(nil)
      expect(matcher.failure_message).to include("links:\n    - link")
    end

    it 'includes error status in the failure message' do
      span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('POST /user')
      span.status = OpenTelemetry::Trace::Status.error('something went wrong')
      span.finish
      matcher = emit_span('GET ')
      matcher.matches?(nil)
      expect(matcher.failure_message).to include('status: error (something went wrong)')
    end

    it 'includes ok status in the failure message' do
      span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('POST /user')
      span.status = OpenTelemetry::Trace::Status.ok
      span.finish
      matcher = emit_span('GET ')
      matcher.matches?(nil)
      expect(matcher.failure_message).to include('status: ok')
    end

    it 'omits status when unset' do
      OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('POST /user').finish
      matcher = emit_span('GET ')
      matcher.matches?(nil)
      expect(matcher.failure_message).to eq(
        "expected span named 'GET ' to have been emitted, but it couldn't be found. " \
        'Found a close matching span named `POST /user`'
      )
    end

    it 'includes all details when present' do
      span = OpenTelemetry.tracer_provider.tracer('rspec-otel')
                          .start_span('POST /user', attributes: { 'hello' => 'world' })
      span.add_event('something happened')
      span.status = OpenTelemetry::Trace::Status.error('oops')
      span.finish
      matcher = emit_span('GET ')
      matcher.matches?(nil)
      expect(matcher.failure_message).to include('attributes:', 'events:', 'status: error (oops)')
    end
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

    it 'matches a span without an event' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test')
        span.finish
      end.to emit_span('test').without_event('testing an event')
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

    it 'matches a span with an exception class' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test')
        span.record_exception(StandardError.new('some error occured'))
        span.finish
      end.to emit_span('test').with_exception(StandardError)
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

  describe 'with_link' do
    it 'matches a span with its link' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test')

        link = OpenTelemetry::Trace::Link.new(span.context, { 'foo' => 'bar' })
        other_span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test links')
        other_span.add_link(link)
        other_span.finish

        span.finish
      end.to emit_span('test links').with_link({ 'foo' => 'bar' })
    end

    it 'matches a span with any link' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test')

        link = OpenTelemetry::Trace::Link.new(span.context)
        other_span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test links')
        other_span.add_link(link)
        other_span.finish

        span.finish
      end.to emit_span('test links').with_link
    end

    it 'does not match a span with a wrong link' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test')

        link = OpenTelemetry::Trace::Link.new(span.context, { 'foo' => 'bar' })
        other_span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test links')
        other_span.add_link(link)
        other_span.finish

        span.finish
      end.not_to emit_span('test links').with_link({ 'hello' => 'world' })
    end
  end

  describe 'without_link' do
    it 'matches a span without the specified link' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test')

        link = OpenTelemetry::Trace::Link.new(span.context, { 'foo' => 'bar' })
        other_span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test links')
        other_span.add_link(link)
        other_span.finish

        span.finish
      end.to emit_span('test links').without_link({ 'hello' => 'world' })
    end

    it 'matches a span with no link at all' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test')
        span.finish
      end.to emit_span('test').without_link
    end

    it 'does not match a span with the link' do
      expect do
        span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test')

        link = OpenTelemetry::Trace::Link.new(span.context, { 'foo' => 'bar' })
        other_span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_span('test links')
        other_span.add_link(link)
        other_span.finish

        span.finish
      end.not_to emit_span('test links').without_link({ 'foo' => 'bar' })
    end
  end

  describe 'as_child' do
    context 'when starting a new trace' do
      it "doesn't match a child span" do
        expect do
          tracer = OpenTelemetry.tracer_provider.tracer('rspec-otel')
          tracer.in_span('root') do |_span|
            span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_root_span('another_root')
            span.finish
          end
        end.not_to emit_span('another_root').as_child
      end
    end

    context 'when continuing the same trace' do
      it 'matches a child span' do
        expect do
          tracer = OpenTelemetry.tracer_provider.tracer('rspec-otel')
          tracer.in_span('root') do |_span|
            tracer.in_span('child') do |span|
              # noop
            end
          end
        end.to emit_span('child').as_child
      end
    end
  end

  describe 'as_root' do
    context 'when starting a new trace' do
      it 'matches a root span' do
        expect do
          tracer = OpenTelemetry.tracer_provider.tracer('rspec-otel')
          tracer.in_span('root') do |_span|
            span = OpenTelemetry.tracer_provider.tracer('rspec-otel').start_root_span('another_root')
            span.finish
          end
        end.to emit_span('another_root').as_root
      end
    end

    context 'when continuing the same trace' do
      it "doesn't match a root span" do
        expect do
          tracer = OpenTelemetry.tracer_provider.tracer('rspec-otel')
          tracer.in_span('root') do |_span|
            tracer.in_span('child') do |span|
              # noop
            end
          end
        end.not_to emit_span('child').as_root
      end
    end
  end
end
