# frozen_string_literal: true

module Ipregistry
  # Base class for every error raised by this library. Rescue it to handle any
  # Ipregistry failure with a single clause:
  #
  #   begin
  #     client.lookup("8.8.8.8")
  #   rescue Ipregistry::Error => e
  #     # ...
  #   end
  class Error < StandardError; end

  # Raised for failures that occur on the client side rather than being
  # reported by the API, such as network errors or a response that cannot be
  # decoded. The underlying cause, when any, is available through #cause.
  class ClientError < Error; end

  # Raised when a connection to the API cannot be established or is
  # interrupted (DNS failure, connection refused, TLS error, ...).
  class ConnectionError < ClientError; end

  # Raised when a request does not complete within the configured timeout.
  class TimeoutError < ClientError; end

  # Raised when a response body cannot be decoded as JSON.
  class ParseError < ClientError; end

  # Raised when the Ipregistry API reports a failure, such as an invalid IP
  # address, an exhausted credit balance, or throttling.
  #
  # Each documented error code maps to a dedicated subclass (for example
  # +INVALID_API_KEY+ raises {InvalidApiKeyError}), so callers can rescue the
  # exact condition they care about. The raw code, the suggested resolution,
  # and the HTTP status remain available on every instance.
  #
  # In batch lookups, an ApiError may also describe the failure of a single
  # entry rather than the whole request (see {BatchResponse}); such per-entry
  # errors are returned, not raised.
  #
  # The full list of error codes is documented at
  # https://ipregistry.co/docs/errors
  class ApiError < Error
    # @return [String, nil] the raw error code returned by the API
    attr_reader :code

    # @return [String, nil] a suggestion on how to resolve the error
    attr_reader :resolution

    # @return [Integer, nil] the HTTP status of the response, when known
    attr_reader :http_status

    def initialize(message = "API error", code: nil, resolution: nil, http_status: nil)
      @code = code
      @resolution = resolution
      @http_status = http_status
      super(message)
    end

    # Builds the most specific error for a decoded API error payload.
    #
    # @param payload [Hash] the decoded error body ("code", "message", "resolution")
    # @param http_status [Integer, nil] the HTTP status of the response
    # @return [ApiError] an instance of the subclass matching the error code,
    #   or of ApiError itself when the code is not recognized
    def self.from_payload(payload, http_status: nil)
      payload = {} unless payload.is_a?(Hash)
      code = payload["code"]
      klass = ERRORS_BY_CODE.fetch(code, ApiError)
      klass.new(
        payload["message"] || "API error",
        code: code,
        resolution: payload["resolution"],
        http_status: http_status
      )
    end
  end

  class BadRequestError < ApiError; end
  class DisabledApiKeyError < ApiError; end
  class ForbiddenIpError < ApiError; end
  class ForbiddenOriginError < ApiError; end
  class ForbiddenIpOriginError < ApiError; end
  class InternalError < ApiError; end
  class InsufficientCreditsError < ApiError; end
  class InvalidApiKeyError < ApiError; end
  class InvalidAsnError < ApiError; end
  class InvalidFilterSyntaxError < ApiError; end
  class InvalidIpAddressError < ApiError; end
  class MissingApiKeyError < ApiError; end
  class ReservedAsnError < ApiError; end
  class ReservedIpAddressError < ApiError; end
  class TooManyAsnsError < ApiError; end
  class TooManyIpsError < ApiError; end
  class TooManyRequestsError < ApiError; end
  class TooManyUserAgentsError < ApiError; end
  class UnknownAsnError < ApiError; end

  # Maps raw Ipregistry API error codes to their dedicated error class. See
  # https://ipregistry.co/docs/errors for the authoritative list.
  ERRORS_BY_CODE = {
    "BAD_REQUEST" => BadRequestError,
    "DISABLED_API_KEY" => DisabledApiKeyError,
    "FORBIDDEN_IP" => ForbiddenIpError,
    "FORBIDDEN_ORIGIN" => ForbiddenOriginError,
    "FORBIDDEN_IP_ORIGIN" => ForbiddenIpOriginError,
    "INTERNAL" => InternalError,
    "INSUFFICIENT_CREDITS" => InsufficientCreditsError,
    "INVALID_API_KEY" => InvalidApiKeyError,
    "INVALID_ASN" => InvalidAsnError,
    "INVALID_FILTER_SYNTAX" => InvalidFilterSyntaxError,
    "INVALID_IP_ADDRESS" => InvalidIpAddressError,
    "MISSING_API_KEY" => MissingApiKeyError,
    "RESERVED_ASN" => ReservedAsnError,
    "RESERVED_IP_ADDRESS" => ReservedIpAddressError,
    "TOO_MANY_ASNS" => TooManyAsnsError,
    "TOO_MANY_IPS" => TooManyIpsError,
    "TOO_MANY_REQUESTS" => TooManyRequestsError,
    "TOO_MANY_USER_AGENTS" => TooManyUserAgentsError,
    "UNKNOWN_ASN" => UnknownAsnError
  }.freeze
end
