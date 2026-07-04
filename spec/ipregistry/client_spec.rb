# frozen_string_literal: true

RSpec.describe Ipregistry::Client do
  subject(:client) { described_class.new(api_key, retry_interval: 0.001) }

  let(:api_key) { "test-key" }
  let(:base_url) { "https://api.ipregistry.co" }

  def stub_lookup(ip, payload: Fixtures.ip_payload(ip), query: nil)
    stub = stub_request(:get, "#{base_url}/#{ip}")
    stub = stub.with(query: query) if query
    stub.to_return(status: 200, body: JSON.generate(payload),
                   headers: { "Content-Type" => "application/json" })
  end

  describe "#initialize" do
    it "rejects a nil API key" do
      expect { described_class.new(nil) }.to raise_error(ArgumentError, /api_key/)
    end

    it "rejects a blank API key" do
      expect { described_class.new("  ") }.to raise_error(ArgumentError, /api_key/)
    end

    it "trims trailing slashes from the base URL" do
      client = described_class.new(api_key, base_url: "https://example.test///")
      expect(client.base_url).to eq("https://example.test")
    end

    it "caps the batch size at the API limit" do
      stub = stub_request(:post, "#{base_url}/")
             .to_return(body: JSON.generate({ "results" => [] }))

      client = described_class.new(api_key, max_batch_size: 5000)
      client.batch_lookup(Array.new(described_class::MAX_BATCH_SIZE) { "8.8.8.8" })

      expect(stub).to have_been_requested.once
    end
  end

  describe "#lookup" do
    it "returns the parsed IP information" do
      stub_lookup("8.8.8.8")

      info = client.lookup("8.8.8.8")

      expect(info).to be_a(Ipregistry::Models::IpInfo)
      expect(info.ip).to eq("8.8.8.8")
      expect(info.location.country.name).to eq("United States")
      expect(info.connection.asn).to eq(15_169)
      expect(info.security.cloud_provider?).to be(true)
    end

    it "sends the expected authentication and content headers" do
      stub = stub_lookup("8.8.8.8")

      client.lookup("8.8.8.8")

      expect(stub.with(headers: {
                         "Authorization" => "ApiKey test-key",
                         "Accept" => "application/json",
                         "User-Agent" => "IpregistryClient/Ruby/#{Ipregistry::VERSION}"
                       })).to have_been_requested.once
    end

    it "rejects an empty IP address" do
      expect { client.lookup("") }.to raise_error(ArgumentError, /lookup_origin/)
    end

    it "rejects a nil IP address" do
      expect { client.lookup(nil) }.to raise_error(ArgumentError)
    end

    it "accepts IPAddr instances" do
      require "ipaddr"
      stub_lookup("8.8.8.8")

      info = client.lookup(IPAddr.new("8.8.8.8"))

      expect(info.ip).to eq("8.8.8.8")
    end

    it "passes fields, hostname, and arbitrary parameters as query string" do
      stub = stub_lookup("8.8.8.8", query: { "fields" => "location,security", "hostname" => "true", "pretty" => "x" })

      client.lookup("8.8.8.8", fields: "location,security", hostname: true, pretty: "x")

      expect(stub).to have_been_requested.once
    end

    it "raises the error subclass matching the API error code" do
      stub_request(:get, "#{base_url}/8.8.8.8")
        .to_return(status: 403, body: JSON.generate(Fixtures.error_payload("INVALID_API_KEY")))

      expect { client.lookup("8.8.8.8") }.to raise_error(Ipregistry::InvalidApiKeyError) do |error|
        expect(error.code).to eq("INVALID_API_KEY")
        expect(error.resolution).to eq("fix it")
        expect(error.http_status).to eq(403)
      end
    end

    it "raises a generic ApiError when the error body is not JSON" do
      stub_request(:get, "#{base_url}/8.8.8.8").to_return(status: 418, body: "teapot")

      expect { client.lookup("8.8.8.8") }
        .to raise_error(Ipregistry::ApiError, /unexpected HTTP status 418/)
    end

    it "raises a ParseError when a 200 body is not JSON" do
      stub_request(:get, "#{base_url}/8.8.8.8").to_return(status: 200, body: "not json")

      expect { client.lookup("8.8.8.8") }.to raise_error(Ipregistry::ParseError)
    end

    context "with a cache" do
      subject(:client) { described_class.new(api_key, cache: Ipregistry::Cache::Memory.new) }

      it "serves repeated lookups from the cache" do
        stub = stub_lookup("8.8.8.8")

        first = client.lookup("8.8.8.8")
        second = client.lookup("8.8.8.8")

        expect(second).to equal(first)
        expect(stub).to have_been_requested.once
      end

      it "does not mix cache entries for different query parameters" do
        stub_lookup("8.8.8.8")
        with_fields = stub_lookup("8.8.8.8", query: { "fields" => "location" })

        client.lookup("8.8.8.8")
        client.lookup("8.8.8.8", fields: "location")

        expect(with_fields).to have_been_requested.once
      end
    end
  end

  describe "#lookup_origin" do
    it "queries the origin endpoint and exposes the parsed User-Agent" do
      payload = Fixtures.ip_payload("203.0.113.10").merge("user_agent" => Fixtures.user_agent_payload)
      stub_request(:get, "#{base_url}/").to_return(status: 200, body: JSON.generate(payload))

      origin = client.lookup_origin

      expect(origin).to be_a(Ipregistry::Models::RequesterIpInfo)
      expect(origin.ip).to eq("203.0.113.10")
      expect(origin.user_agent.name).to eq("Chrome")
    end

    it "returns nil for the User-Agent when the API omits it" do
      stub_request(:get, "#{base_url}/")
        .to_return(status: 200, body: JSON.generate(Fixtures.ip_payload("203.0.113.10")))

      expect(client.lookup_origin.user_agent).to be_nil
    end
  end

  describe "#batch_lookup" do
    def batch_stub
      stub_request(:post, "#{base_url}/").to_return do |request|
        ips = JSON.parse(request.body)
        results = ips.map do |ip|
          ip == "not-an-ip" ? Fixtures.error_payload("INVALID_IP_ADDRESS") : Fixtures.ip_payload(ip)
        end
        { status: 200, body: JSON.generate({ "results" => results }),
          headers: { "Content-Type" => "application/json" } }
      end
    end

    it "returns per-entry results in input order" do
      batch_stub

      response = client.batch_lookup(["8.8.8.8", "not-an-ip", "1.1.1.1"])

      expect(response.size).to eq(3)
      expect(response[0].value.ip).to eq("8.8.8.8")
      expect(response[1]).to be_failure
      expect(response[1].error).to be_a(Ipregistry::InvalidIpAddressError)
      expect(response[2].value.ip).to eq("1.1.1.1")
    end

    it "is enumerable" do
      batch_stub

      response = client.batch_lookup(["8.8.8.8", "not-an-ip"])

      expect(response.count(&:success?)).to eq(1)
      expect(response.values.map(&:ip)).to eq(["8.8.8.8"])
      expect(response.errors.map(&:code)).to eq(["INVALID_IP_ADDRESS"])
    end

    it "raises the failed entry's error from value!" do
      batch_stub

      response = client.batch_lookup(["not-an-ip"])

      expect { response[0].value! }.to raise_error(Ipregistry::InvalidIpAddressError)
    end

    it "splits large batches into chunks and preserves order" do
      requested_bodies = []
      stub_request(:post, "#{base_url}/").to_return do |request|
        ips = JSON.parse(request.body)
        requested_bodies << ips
        { status: 200, body: JSON.generate({ "results" => ips.map { |ip| Fixtures.ip_payload(ip) } }) }
      end

      client = described_class.new(api_key, max_batch_size: 2, batch_concurrency: 2)
      ips = (1..5).map { |i| "10.0.0.#{i}" }
      response = client.batch_lookup(ips)

      expect(requested_bodies.map(&:size).sort).to eq([1, 2, 2])
      expect(response.values.map(&:ip)).to eq(ips)
    end

    it "dispatches chunks sequentially when batch_concurrency is 1" do
      batch_stub

      client = described_class.new(api_key, max_batch_size: 1, batch_concurrency: 1)
      response = client.batch_lookup(["8.8.8.8", "1.1.1.1"])

      expect(response.values.map(&:ip)).to eq(["8.8.8.8", "1.1.1.1"])
    end

    it "raises when the whole request fails" do
      stub_request(:post, "#{base_url}/")
        .to_return(status: 403, body: JSON.generate(Fixtures.error_payload("INSUFFICIENT_CREDITS")))

      expect { client.batch_lookup(["8.8.8.8"]) }.to raise_error(Ipregistry::InsufficientCreditsError)
    end

    it "raises the first chunk error when a sub-request fails" do
      stub_request(:post, "#{base_url}/")
        .to_return(status: 403, body: JSON.generate(Fixtures.error_payload("INSUFFICIENT_CREDITS")))

      client = described_class.new(api_key, max_batch_size: 1, batch_concurrency: 2)

      expect { client.batch_lookup(["8.8.8.8", "1.1.1.1", "9.9.9.9"]) }
        .to raise_error(Ipregistry::InsufficientCreditsError)
    end

    context "with a cache" do
      subject(:client) { described_class.new(api_key, cache: Ipregistry::Cache::Memory.new) }

      it "only requests cache misses and caches fresh entries" do
        stub_lookup("8.8.8.8")
        client.lookup("8.8.8.8")

        requested_bodies = []
        stub_request(:post, "#{base_url}/").to_return do |request|
          ips = JSON.parse(request.body)
          requested_bodies << ips
          { status: 200, body: JSON.generate({ "results" => ips.map { |ip| Fixtures.ip_payload(ip) } }) }
        end

        response = client.batch_lookup(["8.8.8.8", "1.1.1.1"])

        expect(requested_bodies).to eq([["1.1.1.1"]])
        expect(response.values.map(&:ip)).to eq(["8.8.8.8", "1.1.1.1"])

        client.batch_lookup(["8.8.8.8", "1.1.1.1"])
        expect(requested_bodies.size).to eq(1) # everything now cached
      end

      it "does not cache failed entries" do
        stub_request(:post, "#{base_url}/").to_return(
          status: 200,
          body: JSON.generate({ "results" => [Fixtures.error_payload("INVALID_IP_ADDRESS")] })
        )

        client.batch_lookup(["not-an-ip"])
        client.batch_lookup(["not-an-ip"])

        expect(a_request(:post, "#{base_url}/")).to have_been_made.twice
      end
    end

    it "fails the trailing entries when the API returns fewer results than requested" do
      stub_request(:post, "#{base_url}/").to_return(
        status: 200,
        body: JSON.generate({ "results" => [Fixtures.ip_payload("8.8.8.8")] })
      )

      response = client.batch_lookup(["8.8.8.8", "1.1.1.1"])

      expect(response[0]).to be_success
      expect(response[1]).to be_failure
      expect(response[1].error.message).to include("missing result")
    end
  end

  describe "#parse_user_agents" do
    it "posts to the user_agent endpoint and parses the results" do
      stub = stub_request(:post, "#{base_url}/user_agent")
             .with(body: JSON.generate([Fixtures.user_agent_payload["header"]]))
             .to_return(status: 200, body: JSON.generate({ "results" => [Fixtures.user_agent_payload] }))

      response = client.parse_user_agents(Fixtures.user_agent_payload["header"])

      expect(stub).to have_been_requested.once
      ua = response[0].value!
      expect(ua.name).to eq("Chrome")
      expect(ua.operating_system.name).to eq("macOS")
      expect(ua.device.type).to eq("desktop")
    end

    it "accepts an array argument" do
      stub_request(:post, "#{base_url}/user_agent")
        .with(body: JSON.generate(%w[a b]))
        .to_return(status: 200, body: JSON.generate({ "results" => [{}, {}] }))

      expect(client.parse_user_agents(%w[a b]).size).to eq(2)
    end
  end

  describe "retries" do
    it "retries 5xx responses and succeeds" do
      stub_request(:get, "#{base_url}/8.8.8.8")
        .to_return(status: 500, body: "oops")
        .then.to_return(status: 200, body: JSON.generate(Fixtures.ip_payload))

      expect(client.lookup("8.8.8.8").ip).to eq("8.8.8.8")
      expect(a_request(:get, "#{base_url}/8.8.8.8")).to have_been_made.twice
    end

    it "raises after exhausting retries on persistent 5xx" do
      client = described_class.new(api_key, max_retries: 2, retry_interval: 0.001)
      stub_request(:get, "#{base_url}/8.8.8.8").to_return(status: 502, body: "bad gateway")

      expect { client.lookup("8.8.8.8") }.to raise_error(Ipregistry::ApiError, /502/)
      expect(a_request(:get, "#{base_url}/8.8.8.8")).to have_been_made.times(3)
    end

    it "does not retry 5xx when retry_on_server_error is disabled" do
      client = described_class.new(api_key, retry_on_server_error: false, retry_interval: 0.001)
      stub_request(:get, "#{base_url}/8.8.8.8").to_return(status: 500, body: "oops")

      expect { client.lookup("8.8.8.8") }.to raise_error(Ipregistry::ApiError)
      expect(a_request(:get, "#{base_url}/8.8.8.8")).to have_been_made.once
    end

    it "does not retry 429 by default" do
      stub_request(:get, "#{base_url}/8.8.8.8")
        .to_return(status: 429, body: JSON.generate(Fixtures.error_payload("TOO_MANY_REQUESTS")))

      expect { client.lookup("8.8.8.8") }.to raise_error(Ipregistry::TooManyRequestsError)
      expect(a_request(:get, "#{base_url}/8.8.8.8")).to have_been_made.once
    end

    it "retries 429 honoring Retry-After when enabled" do
      client = described_class.new(api_key, retry_on_too_many_requests: true, retry_interval: 0.001)
      stub_request(:get, "#{base_url}/8.8.8.8")
        .to_return(status: 429, headers: { "Retry-After" => "0" },
                   body: JSON.generate(Fixtures.error_payload("TOO_MANY_REQUESTS")))
        .then.to_return(status: 200, body: JSON.generate(Fixtures.ip_payload))

      expect(client.lookup("8.8.8.8").ip).to eq("8.8.8.8")
      expect(a_request(:get, "#{base_url}/8.8.8.8")).to have_been_made.twice
    end

    it "does not retry non-retryable statuses" do
      stub_request(:get, "#{base_url}/8.8.8.8")
        .to_return(status: 400, body: JSON.generate(Fixtures.error_payload("BAD_REQUEST")))

      expect { client.lookup("8.8.8.8") }.to raise_error(Ipregistry::BadRequestError)
      expect(a_request(:get, "#{base_url}/8.8.8.8")).to have_been_made.once
    end

    it "retries timeouts and succeeds" do
      stub_request(:get, "#{base_url}/8.8.8.8")
        .to_timeout
        .then.to_return(status: 200, body: JSON.generate(Fixtures.ip_payload))

      expect(client.lookup("8.8.8.8").ip).to eq("8.8.8.8")
    end

    it "raises a TimeoutError after exhausting retries on timeouts" do
      client = described_class.new(api_key, max_retries: 1, retry_interval: 0.001)
      stub_request(:get, "#{base_url}/8.8.8.8").to_timeout

      expect { client.lookup("8.8.8.8") }.to raise_error(Ipregistry::TimeoutError)
      expect(a_request(:get, "#{base_url}/8.8.8.8")).to have_been_made.twice
    end

    it "retries connection errors and raises a ConnectionError when persistent" do
      client = described_class.new(api_key, max_retries: 1, retry_interval: 0.001)
      stub_request(:get, "#{base_url}/8.8.8.8").to_raise(Errno::ECONNREFUSED)

      expect { client.lookup("8.8.8.8") }.to raise_error(Ipregistry::ConnectionError)
      expect(a_request(:get, "#{base_url}/8.8.8.8")).to have_been_made.twice
    end

    it "retries transport errors even when retry_on_server_error is disabled" do
      client = described_class.new(api_key, retry_on_server_error: false, retry_interval: 0.001)
      stub_request(:get, "#{base_url}/8.8.8.8")
        .to_raise(Errno::ECONNRESET)
        .then.to_return(status: 200, body: JSON.generate(Fixtures.ip_payload))

      expect(client.lookup("8.8.8.8").ip).to eq("8.8.8.8")
    end

    it "performs no retries when max_retries is 0" do
      client = described_class.new(api_key, max_retries: 0, retry_interval: 0.001)
      stub_request(:get, "#{base_url}/8.8.8.8").to_return(status: 500, body: "oops")

      expect { client.lookup("8.8.8.8") }.to raise_error(Ipregistry::ApiError)
      expect(a_request(:get, "#{base_url}/8.8.8.8")).to have_been_made.once
    end
  end
end
