# frozen_string_literal: true

module Ipregistry
  # Ordered results of a batch operation ({Client#batch_lookup} or
  # {Client#parse_user_agents}). Each entry may independently succeed or fail
  # (for example on an invalid IP address), so entries are {Result} objects
  # inspected element by element:
  #
  #   response = client.batch_lookup(["8.8.8.8", "not-an-ip"])
  #   response.each do |result|
  #     if result.success?
  #       puts result.value.location.country.name
  #     else
  #       warn "entry failed: #{result.error.message}"
  #     end
  #   end
  #
  # BatchResponse is Enumerable, so +map+, +select+, +zip+, and friends work
  # as expected. Use {#values} for the successful values only, or
  # {Result#value!} to raise a failed entry's error.
  class BatchResponse
    include Enumerable

    # One entry of a batch operation: either a value (an {Models::IpInfo} or
    # {Models::UserAgent}) or the {ApiError} explaining why this particular
    # entry failed.
    class Result
      # @return [Object, nil] the resolved value, or nil when the entry failed
      attr_reader :value

      # @return [ApiError, nil] the entry's failure, or nil when it succeeded
      attr_reader :error

      def self.success(value)
        new(value: value)
      end

      def self.failure(error)
        new(error: error)
      end

      def initialize(value: nil, error: nil)
        @value = value
        @error = error
      end

      def success?
        @error.nil?
      end

      def failure?
        !success?
      end

      # The resolved value, raising the entry's error when it failed.
      def value!
        raise @error if @error

        @value
      end

      def deconstruct_keys(_keys)
        { value: @value, error: @error }
      end
    end

    # @return [Array<Result>] the entries, in input order
    attr_reader :results

    def initialize(results)
      @results = results.freeze
    end

    # Yields each {Result} in input order.
    def each(&)
      @results.each(&)
    end

    # The {Result} at the given index.
    def [](index)
      @results[index]
    end

    def size
      @results.size
    end
    alias length size

    # The successfully resolved values, in order, skipping failed entries.
    def values
      @results.select(&:success?).map(&:value)
    end

    # The per-entry errors, in order, skipping successful entries.
    # @return [Array<ApiError>]
    def errors
      @results.select(&:failure?).map(&:error)
    end
  end
end
