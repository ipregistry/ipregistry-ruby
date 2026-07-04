[<img src="https://cdn.ipregistry.co/icons/favicon-96x96.png" alt="Ipregistry" width="64"/>](https://ipregistry.co/)
# Ipregistry Ruby Client Library

[![License](http://img.shields.io/:license-apache-blue.svg)](LICENSE)
[![Gem Version](https://img.shields.io/gem/v/ipregistry)](https://rubygems.org/gems/ipregistry)
[![CI](https://github.com/ipregistry/ipregistry-ruby/actions/workflows/ci.yaml/badge.svg)](https://github.com/ipregistry/ipregistry-ruby/actions/workflows/ci.yaml)

This is the official Ruby client library for the [Ipregistry](https://ipregistry.co) IP geolocation and threat data
API, allowing you to look up your own IP address or specified ones. Responses return multiple data points including
carrier, company, currency, location, time zone, threat information, and more. The library can also parse raw
User-Agent strings.

The gem has **zero runtime dependencies** — it is built entirely on the Ruby standard library.

## Getting Started

You'll need an Ipregistry API key, which you can get along with 100,000 free lookups by signing up for a free account
at [https://ipregistry.co](https://ipregistry.co).

### Installation

Add the gem to your application's Gemfile:

```ruby
gem "ipregistry"
```

Or install it directly:

```bash
gem install ipregistry
```

Requires Ruby 3.1 or later.

### Quick start

#### Single IP lookup

```ruby
require "ipregistry"

client = Ipregistry::Client.new("YOUR_API_KEY")

# Look up data for a given IPv4 or IPv6 address.
# On the server side, retrieve the client IP from the request headers.
info = client.lookup("54.85.132.205")

info.location.country.name  # => "United States"
info.location.city          # => "Ashburn"
info.connection.asn         # => 14618
info.security.vpn?          # => false
info.time_zone.id           # => "America/New_York"
```

Every response is a lightweight value object. Nested sections are always present, so chained access like
`info.location.country.name` never raises — absent fields return `nil` and absent flags return `false`. The raw
decoded payload is available through `info.to_h`, and any field (including ones without a dedicated reader) through
`info["field"]`.

#### Origin IP lookup

To look up the IP address the request is sent from — no argument needed — use `lookup_origin`. It returns a
`RequesterIpInfo`, which additionally carries parsed User-Agent data:

```ruby
origin = client.lookup_origin
origin.ip                        # => your public IP
origin.location.country.name
origin.user_agent&.name          # => e.g. "Ruby" (nil when the API omits it)
```

#### Batch IP lookup

`batch_lookup` resolves many IP addresses in a single request. Each entry may independently succeed or fail (for
example on an invalid address), so results are inspected element by element:

```ruby
response = client.batch_lookup(["73.2.2.2", "8.8.8.8", "2001:67c:2e8:22::c100:68b"])

response.each do |result|
  if result.success?
    puts result.value.location.country.name
  else
    # A per-entry error (e.g. invalid IP address); an Ipregistry::ApiError.
    warn "entry failed: #{result.error.message}"
  end
end

response[0].value!         # the first entry's IpInfo, raising its error if it failed
response.values            # only the successfully resolved IpInfo objects, in order
response.errors            # only the per-entry errors, in order
```

`BatchResponse` is `Enumerable`, so `map`, `select`, `zip`, and friends work as expected, and results support
pattern matching (`in { error: Ipregistry::ApiError }`).

The Ipregistry API accepts up to 1024 IP addresses per request. `batch_lookup` transparently splits larger arrays
into several requests, dispatched with bounded concurrency, and reassembles the results in input order — so you can
pass an arbitrarily long array without hitting `TOO_MANY_IPS`. Tune the behavior when needed:

```ruby
client = Ipregistry::Client.new("YOUR_API_KEY",
  max_batch_size: 1024,    # addresses per request (max/default: 1024)
  batch_concurrency: 4)    # concurrent sub-requests (default: 4; 1 = sequential)
```

Only cache misses are sent to the API; if a whole sub-request fails (network or API error), `batch_lookup` raises
that error, whereas an individual bad address surfaces as a per-entry error as shown above.

## Lookup options

Lookups accept keywords that map to Ipregistry query parameters:

```ruby
info = client.lookup("8.8.8.8",
  hostname: true,                            # resolve reverse-DNS hostname
  fields: "location.country.name,security")  # select only these fields
```

| Keyword           | Description                                                                                                                 |
|-------------------|-----------------------------------------------------------------------------------------------------------------------------|
| `hostname:`       | Enable reverse-DNS hostname resolution (disabled by default).                                                              |
| `fields:`         | Restrict the response to the given [fields](https://ipregistry.co/docs/filtering-selecting-fields), reducing payload size. |
| any other keyword | Passed through as an arbitrary query parameter not covered by a dedicated keyword.                                         |

The same keywords are accepted by `lookup_origin` and `batch_lookup`.

## Caching

Although the client has built-in support for in-memory caching, it is **disabled by default** to ensure data freshness.

To enable caching, pass a `Cache::Memory` when constructing the client:

```ruby
client = Ipregistry::Client.new("YOUR_API_KEY", cache: Ipregistry::Cache::Memory.new)
```

The in-memory cache is thread-safe and supports size- and time-based eviction (LRU with a TTL):

```ruby
cache = Ipregistry::Cache::Memory.new(
  max_size: 8192,  # maximum number of entries (default 4096)
  ttl: 600)        # entry lifetime in seconds (default 600)

client = Ipregistry::Client.new("YOUR_API_KEY", cache: cache)
```

Origin (requester) lookups are never cached, because the requester IP is only known from the response. Batch lookups
transparently serve already-cached entries and only request the remainder from the API.

You can provide your own cache backend (Redis, `Rails.cache`, ...) with any object responding to:

```ruby
get(key)         # => value or nil
set(key, value)
delete(key)
clear
```

## Retries

Failed requests are automatically retried with an exponential backoff. By default, up to 3 retries are performed on
transient network errors and 5xx server responses.

Because Ipregistry does not rate limit by default (rate limiting is opt-in per API key), retries on
_429 Too Many Requests_ responses are **disabled by default**. Enable them if your API key is configured with a rate
limit and you want the client to wait and retry (honoring the `Retry-After` header when present):

```ruby
client = Ipregistry::Client.new("YOUR_API_KEY",
  max_retries: 3,                     # 0 disables retries entirely
  retry_interval: 1,                  # base backoff in seconds (interval * 2^attempt)
  retry_on_server_error: true,        # retry on 5xx (default: true)
  retry_on_too_many_requests: true)   # retry on 429 (default: false)
```

## Timeouts and concurrency

By default every request times out after 15 seconds (applied to connection open, read, and write). Adjust it with the
`timeout:` keyword:

```ruby
client = Ipregistry::Client.new("YOUR_API_KEY", timeout: 5)
```

A `Client` is safe for concurrent use, so share one instance across threads; batch lookups already parallelize their
sub-requests internally.

## Errors

Every error raised by the library inherits from `Ipregistry::Error`, so a single rescue clause covers everything:

- **`Ipregistry::ApiError`** — the API reported a failure (e.g. insufficient credits, throttling, invalid input). It
  carries the raw `code`, the suggested `resolution`, and the `http_status`. Each documented error code maps to a
  dedicated subclass, so you can rescue exactly the condition you care about.
- **`Ipregistry::ClientError`** — a client-side failure, further specialized as `ConnectionError`, `TimeoutError`, or
  `ParseError`. The underlying exception, when any, is available through `#cause`.

```ruby
begin
  info = client.lookup("8.8.8.8")
rescue Ipregistry::InsufficientCreditsError
  # handle exhausted credits
rescue Ipregistry::TooManyRequestsError
  # handle rate limiting
rescue Ipregistry::ApiError => e
  # any other API failure
  warn "#{e.message} (#{e.code}): #{e.resolution}"
rescue Ipregistry::ClientError => e
  # network / timeout / decoding error
  warn e.cause&.message || e.message
end
```

Error classes include `BadRequestError`, `DisabledApiKeyError`, `ForbiddenIpError`, `InsufficientCreditsError`,
`InvalidApiKeyError`, `InvalidIpAddressError`, `MissingApiKeyError`, `ReservedIpAddressError`, `TooManyIpsError`,
`TooManyRequestsError`, and more — see `Ipregistry::ERRORS_BY_CODE` for the full mapping and
[ipregistry.co/docs/errors](https://ipregistry.co/docs/errors) for the documented codes.

## Parsing User-Agents

Parse one or more raw User-Agent strings (such as the `User-Agent` header of an incoming request) into structured
data. Like batch lookups, results are per-entry:

```ruby
response = client.parse_user_agents(
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/120.0")

ua = response[0].value!
ua.name                    # => "Chrome"
ua.operating_system.name   # => "macOS"
ua.device.type             # => "desktop"
```

## Filtering bots

You might want to prevent Ipregistry API calls for crawlers or bots browsing your pages. To help identify bots from
the User-Agent, the library includes a lightweight helper:

```ruby
unless Ipregistry.bot?(request.user_agent)
  info = client.lookup(request.remote_ip)
  # ...
end
```

## Examples

Runnable examples live in the [`examples/`](examples) directory. Set your key and run one:

```bash
IPREGISTRY_API_KEY=YOUR_API_KEY ruby examples/single.rb
```

## Testing

The library ships with two tiers of tests:

- **Unit / behavior specs** run offline against [WebMock](https://github.com/bblimke/webmock) stubs — no API key or
  network is required. This is the default `bundle exec rake spec` and what CI runs.
- **System specs** exercise the live Ipregistry API. They live in `spec/system` and are skipped unless
  `IPREGISTRY_API_KEY` is set (each successful lookup consumes credits):

  ```bash
  IPREGISTRY_API_KEY=YOUR_API_KEY bundle exec rake system
  ```

Common tasks are wired through the `Rakefile`: `rake spec`, `rake system`, `rake rubocop`, and `rake build`. The
default task runs RuboCop and the unit specs.

## Other Libraries

There are official Ipregistry client libraries available for many languages including
[Java](https://github.com/ipregistry/ipregistry-java),
[Javascript](https://github.com/ipregistry/ipregistry-javascript),
[Python](https://github.com/ipregistry/ipregistry-python),
[Go](https://github.com/ipregistry/ipregistry-go) and more.

Are you looking for an official client with a programming language or framework we do not support yet?
[Let us know](mailto:support@ipregistry.co).

## License

This library is released under the [Apache 2.0 license](LICENSE).
