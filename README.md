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

You can match the emission of a span with the `have_emitted_span` matcher:

```ruby
require 'spec_helper'

RSpec.describe 'User API' do
  it 'emits a span' do
    expect do
      get :user, id: 1
    end.to have_emitted_span('GET /user').with_attributes({'user.id' => '1'})
  end
end
```

Several conditions can be added to the matcher:

* `with_attributes` - Will match only the spans with the specified attributes.
* `without_attributes` - Will only match the spans that do not have the specified attributes
* `with_event` - Will match only the spans with the specified event.
* `without_event` - Will only match the spans that do not have the specified event
* `with_status` - Will match only the spans that have the proper status.
* `with_exception` - Will match only the spans that have the specified exception event.
* `without_exception` - Will match only the spans that do not have the specified exception event.

The `*_event` condition can be called multiple times with different events.
