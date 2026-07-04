# frozen_string_literal: true

module Ipregistry
  # Caching backends used by {Client} to memoize IP lookups.
  #
  # Only successful single and batch IP lookups are cached. Origin lookups are
  # never cached, because the requester IP is only known from the response.
  #
  # A cache is any object responding to +get(key)+, +set(key, value)+,
  # +delete(key)+, and +clear+, and safe for concurrent use from multiple
  # threads — bring your own backend (Redis, Rails.cache, ...) by satisfying
  # that interface.
  module Cache
    # The default cache: stores nothing, so lookups always hit the API and
    # data is never stale.
    class None
      def get(_key) = nil

      def set(_key, _value) = nil

      def delete(_key) = nil

      def clear = nil
    end

    # A thread-safe, in-process cache with time-based expiration and a bounded
    # size using least-recently-used eviction.
    #
    #   cache = Ipregistry::Cache::Memory.new(max_size: 8192, ttl: 600)
    #   client = Ipregistry::Client.new("YOUR_API_KEY", cache: cache)
    class Memory
      DEFAULT_MAX_SIZE = 4096
      DEFAULT_TTL = 600 # seconds

      # @param max_size [Integer] maximum number of entries held before the
      #   least recently used entry is evicted (default 4096)
      # @param ttl [Numeric] how long, in seconds, an entry stays valid after
      #   being written (default 600)
      # @param clock [#call] overridable monotonic clock, for testing
      def initialize(max_size: DEFAULT_MAX_SIZE, ttl: DEFAULT_TTL,
                     clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
        raise ArgumentError, "max_size must be positive" unless max_size.positive?
        raise ArgumentError, "ttl must be positive" unless ttl.positive?

        @max_size = max_size
        @ttl = ttl
        @clock = clock
        @mutex = Mutex.new
        @entries = {} # key => [value, expires_at]; insertion order tracks recency
      end

      # Returns the cached value for key, or nil when absent or expired.
      def get(key)
        @mutex.synchronize do
          value, expires_at = @entries[key]
          next nil unless expires_at

          if @clock.call > expires_at
            @entries.delete(key)
            next nil
          end

          # Re-insert to mark the entry as most recently used.
          @entries.delete(key)
          @entries[key] = [value, expires_at]
          value
        end
      end

      # Stores value under key, refreshing its expiration and evicting the
      # least recently used entry if the cache is full.
      def set(key, value)
        @mutex.synchronize do
          @entries.delete(key)
          @entries[key] = [value, @clock.call + @ttl]
          @entries.delete(@entries.each_key.first) while @entries.size > @max_size
        end
        nil
      end

      # Removes the entry for key, if present.
      def delete(key)
        @mutex.synchronize { @entries.delete(key) }
        nil
      end

      # Removes every entry.
      def clear
        @mutex.synchronize { @entries.clear }
        nil
      end

      # Current number of entries, including possibly stale ones. Primarily
      # useful in tests.
      def size
        @mutex.synchronize { @entries.size }
      end
    end
  end
end
