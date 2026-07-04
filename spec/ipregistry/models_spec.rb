# frozen_string_literal: true

RSpec.describe Ipregistry::Models do
  describe Ipregistry::Models::IpInfo do
    subject(:info) { described_class.new(Fixtures.ip_payload) }

    it "exposes top-level fields" do
      expect(info.ip).to eq("8.8.8.8")
      expect(info.type).to eq("IPv4")
      expect(info.hostname).to eq("dns.google")
      expect(info).to be_ipv4
      expect(info).not_to be_ipv6
    end

    it "exposes nested location data" do
      location = info.location
      expect(location.city).to eq("Mountain View")
      expect(location.postal).to eq("94043")
      expect(location.latitude).to eq(37.40599)
      expect(location.longitude).to eq(-122.078514)
      expect(location.in_eu?).to be(false)
      expect(location.continent.code).to eq("NA")
      expect(location.region.name).to eq("California")
      expect(location.language.code).to eq("en")
    end

    it "exposes country data including flag, borders, and languages" do
      country = info.location.country
      expect(country.code).to eq("US")
      expect(country.name).to eq("United States")
      expect(country.borders).to eq(%w[CA MX])
      expect(country.tld).to eq(".us")
      expect(country.flag.emoji).to eq("🇺🇸")
      expect(country.languages.map(&:name)).to eq(["English"])
      expect(country.languages.first.native_name).to eq("English")
    end

    it "exposes connection, company, and carrier data" do
      expect(info.connection.asn).to eq(15_169)
      expect(info.connection.route).to eq("8.8.8.0/24")
      expect(info.company.name).to eq("Google LLC")
      expect(info.carrier.mcc).to eq("310")
    end

    it "exposes currency data with nested format" do
      currency = info.currency
      expect(currency.code).to eq("USD")
      expect(currency.symbol).to eq("$")
      expect(currency.format.decimal_separator).to eq(".")
      expect(currency.format.negative.prefix).to eq("-$")
      expect(currency.format.positive.prefix).to eq("$")
    end

    it "exposes security flags as predicates" do
      expect(info.security.cloud_provider?).to be(true)
      expect(info.security.vpn?).to be(false)
      expect(info.security.threat?).to be(false)
      expect(info.security.tor_exit?).to be(false)
    end

    it "exposes time zone data" do
      expect(info.time_zone.id).to eq("America/Los_Angeles")
      expect(info.time_zone.offset).to eq(-25_200)
      expect(info.time_zone.in_daylight_saving?).to be(true)
    end

    it "returns the raw payload from #to_h and #[]" do
      expect(info.to_h).to eq(Fixtures.ip_payload)
      expect(info["ip"]).to eq("8.8.8.8")
      expect(info[:ip]).to eq("8.8.8.8")
    end

    it "compares by class and payload" do
      expect(info).to eq(described_class.new(Fixtures.ip_payload))
      expect(info).not_to eq(described_class.new({}))
    end

    context "when the payload is empty" do
      subject(:info) { described_class.new({}) }

      it "keeps chained access nil-safe" do
        expect(info.ip).to be_nil
        expect(info.location.country.name).to be_nil
        expect(info.location.country.borders).to eq([])
        expect(info.location.country.languages).to eq([])
        expect(info.currency.format.negative.prefix).to be_nil
        expect(info.security.vpn?).to be(false)
        expect(info.location.in_eu?).to be(false)
        expect(info.time_zone.offset).to be_nil
      end
    end

    context "when the payload is nil" do
      it "behaves like an empty payload" do
        info = described_class.new(nil)
        expect(info.location.country.name).to be_nil
      end
    end
  end

  describe Ipregistry::Models::RequesterIpInfo do
    it "exposes the parsed User-Agent when present" do
      info = described_class.new(Fixtures.ip_payload.merge("user_agent" => Fixtures.user_agent_payload))
      expect(info.user_agent.name).to eq("Chrome")
    end

    it "returns nil when the User-Agent is absent" do
      expect(described_class.new(Fixtures.ip_payload).user_agent).to be_nil
    end
  end

  describe Ipregistry::Models::UserAgent do
    subject(:user_agent) { described_class.new(Fixtures.user_agent_payload) }

    it "exposes parsed User-Agent data" do
      expect(user_agent.header).to start_with("Mozilla/5.0")
      expect(user_agent.name).to eq("Chrome")
      expect(user_agent.version_major).to eq("120")
      expect(user_agent.device.brand).to eq("Apple")
      expect(user_agent.engine.name).to eq("Blink")
      expect(user_agent.operating_system.name).to eq("macOS")
      expect(user_agent.os.name).to eq("macOS")
    end
  end
end
