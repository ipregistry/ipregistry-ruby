# frozen_string_literal: true

RSpec.describe Ipregistry do
  it "has a semantic version number" do
    expect(Ipregistry::VERSION).to match(/\A\d+\.\d+\.\d+(-[0-9A-Za-z.]+)?\z/)
  end

  describe ".bot?" do
    it "detects common crawler markers case-insensitively" do
      expect(described_class.bot?("Googlebot/2.1 (+http://www.google.com/bot.html)")).to be(true)
      expect(described_class.bot?("Mozilla/5.0 (compatible; Baiduspider/2.0)")).to be(true)
      expect(described_class.bot?("Yahoo! Slurp")).to be(true)
      expect(described_class.bot?("SPIDER")).to be(true)
    end

    it "does not flag regular browsers" do
      expect(described_class.bot?("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/120.0")).to be(false)
    end

    it "handles nil and empty values" do
      expect(described_class.bot?(nil)).to be(false)
      expect(described_class.bot?("")).to be(false)
    end
  end
end
