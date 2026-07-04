# frozen_string_literal: true

RSpec.describe Ipregistry::ApiError do
  describe ".from_payload" do
    it "builds the subclass matching a known error code" do
      error = described_class.from_payload(Fixtures.error_payload("INSUFFICIENT_CREDITS"), http_status: 403)

      expect(error).to be_a(Ipregistry::InsufficientCreditsError)
      expect(error.code).to eq("INSUFFICIENT_CREDITS")
      expect(error.message).to eq("something went wrong")
      expect(error.resolution).to eq("fix it")
      expect(error.http_status).to eq(403)
    end

    it "maps every documented error code to a dedicated class" do
      expect(Ipregistry::ERRORS_BY_CODE.keys).to include(
        "BAD_REQUEST", "DISABLED_API_KEY", "FORBIDDEN_IP", "FORBIDDEN_ORIGIN", "FORBIDDEN_IP_ORIGIN",
        "INTERNAL", "INSUFFICIENT_CREDITS", "INVALID_API_KEY", "INVALID_ASN", "INVALID_FILTER_SYNTAX",
        "INVALID_IP_ADDRESS", "MISSING_API_KEY", "RESERVED_ASN", "RESERVED_IP_ADDRESS", "TOO_MANY_ASNS",
        "TOO_MANY_IPS", "TOO_MANY_REQUESTS", "TOO_MANY_USER_AGENTS", "UNKNOWN_ASN"
      )
      Ipregistry::ERRORS_BY_CODE.each_value do |klass|
        expect(klass).to be < described_class
      end
    end

    it "falls back to ApiError for unknown codes" do
      error = described_class.from_payload(Fixtures.error_payload("BRAND_NEW_CODE"))

      expect(error.class).to eq(described_class)
      expect(error.code).to eq("BRAND_NEW_CODE")
    end

    it "tolerates malformed payloads" do
      error = described_class.from_payload("not a hash", http_status: 500)

      expect(error).to be_a(described_class)
      expect(error.message).to eq("API error")
      expect(error.http_status).to eq(500)
    end
  end

  it "is rescuable via the library base error" do
    expect(Ipregistry::InvalidApiKeyError.new).to be_a(Ipregistry::Error)
    expect(Ipregistry::ConnectionError.new).to be_a(Ipregistry::Error)
    expect(Ipregistry::TimeoutError.new).to be_a(Ipregistry::ClientError)
    expect(Ipregistry::ParseError.new).to be_a(Ipregistry::ClientError)
  end
end
