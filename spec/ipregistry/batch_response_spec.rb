# frozen_string_literal: true

RSpec.describe Ipregistry::BatchResponse do
  let(:error) { Ipregistry::InvalidIpAddressError.new("invalid", code: "INVALID_IP_ADDRESS") }
  let(:response) do
    described_class.new([
                          described_class::Result.success("first"),
                          described_class::Result.failure(error),
                          described_class::Result.success("third")
                        ])
  end

  it "preserves order and supports indexing" do
    expect(response.size).to eq(3)
    expect(response.length).to eq(3)
    expect(response[0].value).to eq("first")
    expect(response[1].error).to eq(error)
    expect(response[2].value).to eq("third")
  end

  it "is enumerable" do
    expect(response.map(&:success?)).to eq([true, false, true])
    expect(response.select(&:failure?).size).to eq(1)
  end

  it "exposes successful values and errors separately" do
    expect(response.values).to eq(%w[first third])
    expect(response.errors).to eq([error])
  end

  it "supports pattern matching on results" do
    case response[1]
    in { error: Ipregistry::ApiError => matched }
      expect(matched.code).to eq("INVALID_IP_ADDRESS")
    end
  end

  describe Ipregistry::BatchResponse::Result do
    it "reports success" do
      result = described_class.success("value")
      expect(result).to be_success
      expect(result).not_to be_failure
      expect(result.value).to eq("value")
      expect(result.error).to be_nil
      expect(result.value!).to eq("value")
    end

    it "reports failure and raises from value!" do
      error = Ipregistry::ApiError.new("boom")
      result = described_class.failure(error)
      expect(result).to be_failure
      expect(result.value).to be_nil
      expect { result.value! }.to raise_error(Ipregistry::ApiError, "boom")
    end
  end
end
