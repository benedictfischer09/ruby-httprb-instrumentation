# HTTP Opentracing

Open Tracing instrumentation for the [http gem](https://github.com/httprb/http). By default it starts a new span for every request and follows the open tracing tagging [semantic conventions](https://opentracing.io/specification/conventions)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'httprb-opentracing'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install httprb-opentracing

## Usage
First load the instrumentation (Note: this won't automatically instrument the http gem)
```
require "httprb-opentracing"
```

If you have setup `OpenTracing.global_tracer` you can turn on spans for all requests with just:
```
    HTTP::Tracer.instrument
```

If you need more control over the tracer or which requests get their own span you can configure both settings like:
```
    HTTP::Tracer.instrument(
        tracer: tracer,
        ignore_request: ->(request, opts) { request.uri.host == 'localhost' }
    )
```

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `rspec` to run the tests.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/benedictfischer09/ruby-httprb-instrumentation. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/benedictfischer09/ruby-httprb-instrumentation/blob/master/CODE_OF_CONDUCT.md).
