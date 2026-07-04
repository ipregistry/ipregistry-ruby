# frozen_string_literal: true

# System specs exercise the live Ipregistry API. They are excluded from the
# normal test run (`rake spec`) and executed with:
#
#   IPREGISTRY_API_KEY=YOUR_API_KEY bundle exec rake system
#
# A valid API key is required; each successful lookup consumes credits. The
# specs skip cleanly when the key is absent.
RSpec.describe "Ipregistry live API", :system do
  subject(:client) { Ipregistry::Client.new(api_key) }

  let(:api_key) { ENV.fetch("IPREGISTRY_API_KEY", nil) }

  before do
    skip "set IPREGISTRY_API_KEY to run system specs" if api_key.nil? || api_key.empty?
  end

  describe "single lookup" do
    it "returns data for a well-known address" do
      info = client.lookup("8.8.8.8")

      expect(info.ip).to eq("8.8.8.8")
      expect(info).to be_ipv4
      expect(info.location.country.code).not_to be_nil
      expect(info.connection.asn).to be_a(Integer)
    end

    it "honors field selection" do
      info = client.lookup("8.8.8.8", fields: "location.country.name")

      expect(info.location.country.name).not_to be_nil
      expect(info.to_h.keys).to contain_exactly("location")
    end
  end

  describe "origin lookup" do
    it "returns the requester's own IP" do
      origin = client.lookup_origin

      expect(origin.ip).not_to be_nil
      expect(origin.ip).not_to be_empty
    end
  end

  describe "batch lookup" do
    it "resolves entries independently, surfacing per-entry failures" do
      response = client.batch_lookup(["8.8.8.8", "1.1.1.1", "not-an-ip"])

      expect(response.size).to eq(3)
      expect(response[0]).to be_success
      expect(response[0].value.ip).to eq("8.8.8.8")
      expect(response[1]).to be_success
      expect(response[2]).to be_failure
      expect(response[2].error).to be_a(Ipregistry::ApiError)
    end
  end

  describe "error handling" do
    it "raises InvalidIpAddressError for an invalid address" do
      expect { client.lookup("invalid") }.to raise_error(Ipregistry::InvalidIpAddressError) do |error|
        expect(error.code).to eq("INVALID_IP_ADDRESS")
      end
    end

    it "raises an authentication error for a bad API key" do
      bad_client = Ipregistry::Client.new("obviously-invalid-key")

      expect { bad_client.lookup("8.8.8.8") }.to raise_error(Ipregistry::ApiError) do |error|
        expect(error.http_status).to be_between(400, 499)
      end
    end
  end

  describe "user agent parsing" do
    it "parses a raw User-Agent string" do
      response = client.parse_user_agents(
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
        "(KHTML, like Gecko) Chrome/120.0 Safari/537.36"
      )

      ua = response[0].value!
      expect(ua.name).not_to be_nil
    end
  end
end
