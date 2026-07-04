# frozen_string_literal: true

module Ipregistry
  # Value objects wrapping the JSON payloads returned by the Ipregistry API.
  #
  # Nested objects are always present (never nil), so chained access such as
  # +info.location.country.name+ never raises even when the API omitted a
  # section; absent fields return nil and absent flags return false.
  module Models
    # Base class for all response models. Wraps the decoded JSON hash and
    # exposes convenient readers declared with a small class-level DSL.
    class Base
      # @param data [Hash, nil] the decoded JSON payload
      def initialize(data = {})
        @data = data.is_a?(Hash) ? data : {}
      end

      # The raw decoded payload backing this model.
      # @return [Hash]
      def to_h
        @data
      end

      # Raw access to any field of the payload, including ones without a
      # dedicated reader.
      def [](key)
        @data[key.to_s]
      end

      def ==(other)
        other.instance_of?(self.class) && other.to_h == @data
      end
      alias eql? ==

      def hash
        [self.class, @data].hash
      end

      def inspect
        "#<#{self.class.name} #{@data.inspect}>"
      end

      class << self
        private

        # Declares readers returning the raw value of same-named JSON fields.
        def field(*names)
          names.each do |name|
            key = name.to_s
            define_method(name) { @data[key] }
          end
        end

        # Declares a predicate method (+name?+) for a boolean JSON field.
        def flag(name, key: name.to_s)
          define_method(:"#{name}?") { @data[key] ? true : false }
        end

        # Declares a reader wrapping a nested JSON object in another model.
        # The wrapped object is always returned, even when the field is
        # absent, so chained access is nil-safe.
        def embeds(name, model, key: name.to_s)
          define_method(name) do
            @embedded ||= {}
            @embedded[name] ||= Models.const_get(model).new(@data[key])
          end
        end

        # Declares a reader wrapping a nested JSON array in a list of models.
        def embeds_many(name, model, key: name.to_s)
          define_method(name) do
            @embedded ||= {}
            @embedded[name] ||= begin
              klass = Models.const_get(model)
              elements = @data[key]
              elements.is_a?(Array) ? elements.map { |element| klass.new(element) }.freeze : [].freeze
            end
          end
        end
      end
    end
  end
end
