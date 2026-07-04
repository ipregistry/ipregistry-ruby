# frozen_string_literal: true

RSpec.describe Ipregistry::Cache do
  describe Ipregistry::Cache::None do
    subject(:cache) { described_class.new }

    it "stores nothing" do
      cache.set("key", "value")
      expect(cache.get("key")).to be_nil
    end
  end

  describe Ipregistry::Cache::Memory do
    it "stores and retrieves values" do
      cache = described_class.new
      cache.set("key", "value")
      expect(cache.get("key")).to eq("value")
    end

    it "returns nil for missing keys" do
      expect(described_class.new.get("missing")).to be_nil
    end

    it "rejects non-positive sizes and TTLs" do
      expect { described_class.new(max_size: 0) }.to raise_error(ArgumentError)
      expect { described_class.new(ttl: 0) }.to raise_error(ArgumentError)
    end

    it "deletes entries" do
      cache = described_class.new
      cache.set("key", "value")
      cache.delete("key")
      expect(cache.get("key")).to be_nil
    end

    it "clears all entries" do
      cache = described_class.new
      cache.set("a", 1)
      cache.set("b", 2)
      cache.clear
      expect(cache.size).to eq(0)
    end

    context "with a controllable clock" do
      let(:now) { [0.0] }
      let(:cache) { described_class.new(ttl: 10, clock: -> { now[0] }) }

      it "expires entries after the TTL" do
        cache.set("key", "value")
        now[0] = 9.9
        expect(cache.get("key")).to eq("value")
        now[0] = 10.1
        expect(cache.get("key")).to be_nil
        expect(cache.size).to eq(0)
      end

      it "refreshes the expiration on set" do
        cache.set("key", "old")
        now[0] = 8.0
        cache.set("key", "new")
        now[0] = 15.0
        expect(cache.get("key")).to eq("new")
      end
    end

    context "with a bounded size" do
      let(:cache) { described_class.new(max_size: 2) }

      it "evicts the least recently used entry when full" do
        cache.set("a", 1)
        cache.set("b", 2)
        cache.set("c", 3)

        expect(cache.get("a")).to be_nil
        expect(cache.get("b")).to eq(2)
        expect(cache.get("c")).to eq(3)
      end

      it "counts a get as a use" do
        cache.set("a", 1)
        cache.set("b", 2)
        cache.get("a") # bump "a" so "b" becomes the eviction candidate
        cache.set("c", 3)

        expect(cache.get("a")).to eq(1)
        expect(cache.get("b")).to be_nil
      end

      it "does not grow when overwriting an existing key" do
        cache.set("a", 1)
        cache.set("b", 2)
        cache.set("a", 3)

        expect(cache.size).to eq(2)
        expect(cache.get("a")).to eq(3)
        expect(cache.get("b")).to eq(2)
      end
    end

    it "is safe under concurrent access" do
      cache = described_class.new(max_size: 64)
      threads = Array.new(8) do |t|
        Thread.new do
          100.times do |i|
            cache.set("key-#{t}-#{i % 16}", i)
            cache.get("key-#{t}-#{i % 16}")
            cache.delete("key-#{t}-#{i % 16}") if (i % 10).zero?
          end
        end
      end
      threads.each(&:join)

      expect(cache.size).to be <= 64
    end
  end
end
