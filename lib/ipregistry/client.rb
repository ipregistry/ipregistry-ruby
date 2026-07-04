# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "uri"

module Ipregistry
  # Client for the Ipregistry API. A Client is safe for concurrent use by
  # multiple threads.
  #
  #   client = Ipregistry::Client.new("YOUR_API_KEY")
  #   info = client.lookup("8.8.8.8")
  #   info.location.country.name # => "United States"
  #
  # By default the client uses a 15-second timeout, retries transient failures
  # up to three times, and performs no caching. Behavior is customized with
  # keyword arguments to {#initialize}.
  class Client
    # Base URL of the Ipregistry API used unless overridden with +base_url:+.
    DEFAULT_BASE_URL = "https://api.ipregistry.co"

    # Maximum number of IP addresses Ipregistry accepts in a single batch
    # request. {#batch_lookup} transparently splits larger arrays into several
    # requests so callers never have to.
    MAX_BATCH_SIZE = 1024

    DEFAULT_TIMEOUT = 15 # seconds
    DEFAULT_MAX_RETRIES = 3
    DEFAULT_RETRY_INTERVAL = 1.0 # seconds
    DEFAULT_BATCH_CONCURRENCY = 4

    # Default value of the User-Agent header sent with requests.
    USER_AGENT = "IpregistryClient/Ruby/#{VERSION}".freeze

    # Errors raised by Net::HTTP when a request does not complete in time.
    TIMEOUT_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout].freeze
    private_constant :TIMEOUT_ERRORS

    # Errors raised by Net::HTTP for connection-level failures.
    CONNECTION_ERRORS = [SocketError, SystemCallError, IOError, EOFError, OpenSSL::SSL::SSLError].freeze
    private_constant :CONNECTION_ERRORS

    # @return [Object] the cache used by the client
    attr_reader :cache

    # @return [String] the API base URL
    attr_reader :base_url

    # Creates a client authenticating with the given API key. You can obtain
    # a key, along with a generous free tier, at https://ipregistry.co.
    #
    # @param api_key [String] your Ipregistry API key
    # @param base_url [String] overrides the API base URL, mainly useful for
    #   testing or pointing at a private deployment
    # @param timeout [Numeric] per-request timeout in seconds, applied to
    #   connection open, read, and write (default 15)
    # @param max_retries [Integer] maximum number of automatic retries
    #   performed in addition to the initial attempt; 0 disables retries
    #   (default 3)
    # @param retry_interval [Numeric] base backoff in seconds between retries;
    #   successive retries use an exponentially increasing delay
    #   (interval * 2^attempt), and a 429 response carrying a Retry-After
    #   header takes precedence (default 1)
    # @param retry_on_server_error [Boolean] whether 5xx responses are retried
    #   (default true); transient network errors are always retried
    # @param retry_on_too_many_requests [Boolean] whether 429 Too Many
    #   Requests responses are retried, honoring the Retry-After header when
    #   present. Ipregistry does not rate limit by default (it is opt-in per
    #   API key), so this defaults to false
    # @param cache [Object] response cache; disabled by default so that data
    #   is never stale. Pass an {Cache::Memory} instance or any object with
    #   the same interface
    # @param max_batch_size [Integer] maximum number of IP addresses sent in a
    #   single batch request, capped at {MAX_BATCH_SIZE} (the API limit)
    # @param batch_concurrency [Integer] how many batch sub-requests
    #   {#batch_lookup} dispatches concurrently when an array is large enough
    #   to be split into chunks; 1 means strictly sequential dispatch, which
    #   is gentler on a rate-limited API key (default 4)
    # @param user_agent [String] overrides the User-Agent header sent with
    #   requests
    def initialize(api_key,
                   base_url: DEFAULT_BASE_URL,
                   timeout: DEFAULT_TIMEOUT,
                   max_retries: DEFAULT_MAX_RETRIES,
                   retry_interval: DEFAULT_RETRY_INTERVAL,
                   retry_on_server_error: true,
                   retry_on_too_many_requests: false,
                   cache: Cache::None.new,
                   max_batch_size: MAX_BATCH_SIZE,
                   batch_concurrency: DEFAULT_BATCH_CONCURRENCY,
                   user_agent: USER_AGENT)
      raise ArgumentError, "api_key must not be nil or empty" if api_key.nil? || api_key.to_s.strip.empty?

      @api_key = api_key.to_s
      @base_url = base_url.to_s.sub(%r{/+\z}, "")
      @timeout = timeout
      @max_retries = [max_retries.to_i, 0].max
      @retry_interval = retry_interval
      @retry_on_server_error = retry_on_server_error
      @retry_on_too_many_requests = retry_on_too_many_requests
      @cache = cache || Cache::None.new
      @max_batch_size = max_batch_size.to_i.clamp(1, MAX_BATCH_SIZE)
      @batch_concurrency = [batch_concurrency.to_i, 1].max
      @user_agent = user_agent
    end

    # Returns the data associated with the given IP address. The ip argument
    # must be a non-empty IPv4 or IPv6 address (String or IPAddr); to look up
    # the requester's own IP, use {#lookup_origin} instead.
    #
    # When a cache is configured, a hit is returned without contacting the
    # API.
    #
    # @param ip [String, IPAddr] the IP address to look up
    # @param fields [String, nil] restricts the response to the given fields,
    #   using Ipregistry's field selector syntax (for example
    #   "location.country.name,security"). This reduces payload size and, in
    #   some cases, credit usage. See
    #   https://ipregistry.co/docs/filtering-selecting-fields
    # @param hostname [Boolean, nil] enables reverse-DNS hostname resolution
    #   (disabled by default)
    # @param params [Hash] arbitrary extra query parameters not covered by a
    #   dedicated keyword
    # @return [Models::IpInfo]
    # @raise [ApiError, ClientError]
    def lookup(ip, fields: nil, hostname: nil, **params)
      ip = ip.to_s.strip
      raise ArgumentError, "ip must not be empty; use #lookup_origin for the requester IP" if ip.empty?

      query = build_query(fields: fields, hostname: hostname, **params)
      key = cache_key(ip, query)
      cached = @cache.get(key)
      return cached if cached

      info = Models::IpInfo.new(request_json(:get, url_for(ip, query)))
      @cache.set(key, info)
      info
    end

    # Returns the data associated with the IP address the request originates
    # from, enriched with parsed User-Agent data. Origin lookups are never
    # cached, because the requester IP is only known from the response.
    #
    # Accepts the same keywords as {#lookup}.
    #
    # @return [Models::RequesterIpInfo]
    # @raise [ApiError, ClientError]
    def lookup_origin(fields: nil, hostname: nil, **params)
      query = build_query(fields: fields, hostname: hostname, **params)
      Models::RequesterIpInfo.new(request_json(:get, url_for("", query)))
    end

    # Resolves several IP addresses at once. The returned {BatchResponse}
    # preserves the order of ips, and each entry may independently succeed or
    # fail; a raised error indicates the whole request failed (for example
    # authentication or a network error), not the failure of an individual
    # entry.
    #
    # The Ipregistry API accepts up to {MAX_BATCH_SIZE} addresses per request;
    # larger arrays are transparently split into several requests dispatched
    # with bounded concurrency (see +max_batch_size:+ and
    # +batch_concurrency:+) and reassembled in input order.
    #
    # Entries already present in the cache are served locally; only the
    # remainder are requested from the API, and freshly resolved entries are
    # cached. Accepts the same keywords as {#lookup}.
    #
    # @param ips [Array<String, IPAddr>] the IP addresses to look up
    # @return [BatchResponse]
    # @raise [ApiError, ClientError]
    def batch_lookup(ips, fields: nil, hostname: nil, **params)
      ips = Array(ips).map { |ip| ip.to_s.strip }
      query = build_query(fields: fields, hostname: hostname, **params)

      cached = ips.map { |ip| @cache.get(cache_key(ip, query)) }
      misses = ips.zip(cached).reject { |_, hit| hit }.map(&:first)
      fresh = resolve_misses(misses, query)

      BatchResponse.new(assemble_batch_results(ips, cached, fresh, query))
    end

    # Parses one or more raw User-Agent strings (such as the User-Agent
    # header of an incoming HTTP request) into structured data. Results
    # preserve the order of the input.
    #
    #   response = client.parse_user_agents("Mozilla/5.0 ...")
    #   response[0].value!.name # => "Chrome"
    #
    # @param user_agents [Array<String>] the User-Agent strings to parse
    # @return [BatchResponse]
    # @raise [ApiError, ClientError]
    def parse_user_agents(*user_agents)
      body = JSON.generate(user_agents.flatten.map(&:to_s))
      data = request_json(:post, "#{@base_url}/user_agent", body: body)
      BatchResponse.new(parse_batch_results(data) { |entry| Models::UserAgent.new(entry) })
    end

    private

    # Merges cached entries and freshly resolved results back into input
    # order, caching newly successful entries along the way.
    def assemble_batch_results(ips, cached, fresh, query)
      next_fresh = -1
      ips.each_with_index.map do |ip, i|
        next BatchResponse::Result.success(cached[i]) if cached[i]

        result = fresh[next_fresh += 1]
        # Defensive: the API returned fewer results than requested.
        result ||= BatchResponse::Result.failure(ApiError.new("missing result for requested IP address"))
        @cache.set(cache_key(ip, query), result.value) if result.success?
        result
      end
    end

    # Fetches fresh data for the cache-missed IP addresses, splitting them
    # into API-sized chunks dispatched with bounded concurrency when needed.
    # The returned results preserve the order of misses.
    def resolve_misses(misses, query)
      return [] if misses.empty?

      chunks = misses.each_slice(@max_batch_size).to_a
      return batch_request(chunks.first, query) if chunks.size == 1

      resolve_chunks(chunks, query).flatten(1)
    end

    # Dispatches batch chunks with at most batch_concurrency requests in
    # flight and returns their results in order. If any chunk fails, the
    # first error is raised once all in-flight requests have finished, and
    # queued chunks are not started.
    def resolve_chunks(chunks, query)
      chunk_results = Array.new(chunks.size)
      jobs = Queue.new
      chunks.each_with_index { |chunk, index| jobs << [chunk, index] }
      jobs.close

      mutex = Mutex.new
      first_error = nil

      workers = Array.new([@batch_concurrency, chunks.size].min) do
        Thread.new do
          while (job = jobs.pop)
            break if mutex.synchronize { first_error }

            chunk, index = job
            begin
              chunk_results[index] = batch_request(chunk, query)
            rescue Error => e
              mutex.synchronize { first_error ||= e }
            end
          end
        end
      end
      workers.each(&:join)

      raise first_error if first_error

      chunk_results
    end

    # Performs a single POST batch request and returns per-entry results.
    def batch_request(ips, query)
      data = request_json(:post, url_for("", query), body: JSON.generate(ips))
      parse_batch_results(data) { |entry| Models::IpInfo.new(entry) }
    end

    # Maps the {"results" => [...]} envelope of a batch response to an array
    # of Results, treating elements carrying an error code as failures.
    def parse_batch_results(data)
      entries = data.is_a?(Hash) && data["results"].is_a?(Array) ? data["results"] : []
      entries.map do |entry|
        if entry.is_a?(Hash) && entry["code"]
          BatchResponse::Result.failure(ApiError.from_payload(entry))
        else
          BatchResponse::Result.success(yield(entry))
        end
      end
    end

    # Collapses lookup keywords into a deterministic, sorted query hash.
    def build_query(fields:, hostname:, **params)
      query = params.transform_keys(&:to_s)
      query["fields"] = fields unless fields.nil?
      query["hostname"] = hostname unless hostname.nil?
      query.transform_values!(&:to_s)
      query.sort.to_h
    end

    def url_for(ip, query)
      url = "#{@base_url}/#{ip}"
      url += "?#{URI.encode_www_form(query)}" unless query.empty?
      url
    end

    # Derives a deterministic cache key from an IP address and its query
    # parameters (already sorted by build_query).
    def cache_key(ip, query)
      return ip if query.empty?

      "#{ip};#{URI.encode_www_form(query)}"
    end

    # Performs an HTTP request with automatic retries and returns the decoded
    # 2xx response body. Non-2xx responses raise an {ApiError} subclass;
    # transport and decoding failures raise a {ClientError} subclass.
    def request_json(http_method, url, body: nil)
      attempt = 0
      loop do
        response = attempt_request(http_method, url, body, attempt)

        if response
          status = response.code.to_i
          return parse_json(response.body.to_s) if status.between?(200, 299)
          raise api_error(response, status) unless retry_status?(status) && attempt < @max_retries

          wait(backoff_delay(attempt, retry_after(response)))
        else
          # A transport error was swallowed by attempt_request: retry.
          wait(backoff_delay(attempt, nil))
        end

        attempt += 1
      end
    end

    # Performs one HTTP attempt. Transport errors are re-raised as typed
    # ClientError subclasses once retries are exhausted, and otherwise
    # swallowed (returning nil) so the caller backs off and retries;
    # transient network errors are always retried, regardless of the
    # retry-on-status flags.
    def attempt_request(http_method, url, body, attempt)
      perform(http_method, url, body)
    rescue *TIMEOUT_ERRORS
      raise Ipregistry::TimeoutError, "request timed out after #{@timeout}s" if attempt >= @max_retries

      nil
    rescue *CONNECTION_ERRORS => e
      raise Ipregistry::ConnectionError, "request failed: #{e.message}" if attempt >= @max_retries

      nil
    end

    def perform(http_method, url, body)
      uri = URI.parse(url)
      request = build_request(http_method, uri, body)

      Net::HTTP.start(uri.host, uri.port,
                      use_ssl: uri.scheme == "https",
                      open_timeout: @timeout,
                      read_timeout: @timeout,
                      write_timeout: @timeout) do |http|
        http.request(request)
      end
    end

    def build_request(http_method, uri, body)
      request = case http_method
                when :get then Net::HTTP::Get.new(uri)
                when :post then Net::HTTP::Post.new(uri)
                else raise ArgumentError, "unsupported HTTP method: #{http_method}"
                end
      request["Authorization"] = "ApiKey #{@api_key}"
      request["User-Agent"] = @user_agent
      request["Accept"] = "application/json"
      if body
        request["Content-Type"] = "application/json"
        request.body = body
      end
      request
    end

    def parse_json(body)
      JSON.parse(body)
    rescue JSON::ParserError
      raise ParseError, "failed to decode response body as JSON"
    end

    # Converts a non-2xx response into the most specific ApiError, falling
    # back to a generic message when the body is not a recognizable error
    # payload.
    def api_error(response, status)
      payload = begin
        JSON.parse(response.body.to_s)
      rescue JSON::ParserError
        nil
      end

      if payload.is_a?(Hash) && payload["code"]
        ApiError.from_payload(payload, http_status: status)
      else
        ApiError.new("unexpected HTTP status #{status}", http_status: status)
      end
    end

    def retry_status?(status)
      return @retry_on_too_many_requests if status == 429

      status.between?(500, 599) && @retry_on_server_error
    end

    # Delay before the next retry attempt, honoring an explicit Retry-After
    # duration when positive and otherwise using exponential backoff.
    def backoff_delay(attempt, retry_after)
      return retry_after if retry_after&.positive?

      @retry_interval * (2**[attempt, 30].min)
    end

    # Parses a Retry-After header expressed as an integer number of seconds.
    # Returns nil when the header is absent or not a valid non-negative
    # integer (the HTTP-date form is not supported).
    def retry_after(response)
      value = response["Retry-After"]
      return nil unless value&.match?(/\A\d+\z/)

      Integer(value, 10)
    end

    def wait(seconds)
      sleep(seconds) if seconds.positive?
    end
  end
end
