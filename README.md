# RSpec Otel

RSpec matchers to be used with the OpenTelemetry framework

## Installation

Add this line to your Gemfile:

```ruby
gem 'rspec-otel'
```

Within your spec helper, require the gem:

```ruby
require 'rspec_otel'
```

And include the matchers within the rspec configuration:

```ruby
RSpec.configure do |config|
  config.include RspecOtel::Matchers
end
```

## Usage

### Matching the presence of a span

You can match the emission of a span with the `emit_span` matcher:

```ruby
require 'spec_helper'

RSpec.describe 'User API' do
  it 'emits a span' do
    expect do
      get :user, id: 1
    end.to emit_span('GET /user')
  end
end
```

`emit_span` will also match a regular expression:

```ruby
require 'spec_helper'

RSpec.describe 'User API' do
  it 'emits a span' do
    expect do
      get :user, id: 1
    end.to emit_span(/^GET /)
  end
end
```

Several conditions can be added to the matcher:

* `as_root` - Will match spans that are the root of a trace.
* `as_child` - Will match spans that are not the root of a trace
* `with_attributes` - Will match only the spans with the specified attributes.
* `without_attributes` - Will only match the spans that do not have the specified attributes
* `with_event` - Will match only the spans with the specified event.
* `without_event` - Will only match the spans that do not have the specified event
* `with_link` - Will match only the spans with the specified link.
* `without_link` - Will only match the spans that do not have the specified link
* `with_status` - Will match only the spans that have the proper status.
* `with_exception` - Will match only the spans that have the specified exception event.
* `without_exception` - Will match only the spans that do not have the specified exception event.

_The `*_event` condition can be called multiple times with different events._


### Disabling

We wrap every example in a new OpenTelemetry SDK configuration by default, if you wish to disable this you can tag your example with `:rspec_otel_disable_tracing`:

```ruby
require 'spec_helper'

RSpec.describe 'User API', :rspec_otel_disable_tracing do
  it 'tests my code' do
    expect(true).to be true
  end
end
```

## Compatibility

RSpec Otel ensures compatibility with the currently supported versions of the
[Ruby Language](https://www.ruby-lang.org/en/downloads/branches/).
