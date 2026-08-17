# frozen_string_literal: true

module Ipregistry
  module Models
    # Mobile carrier information associated with an IP address. MCC is the
    # Mobile Country Code and MNC the Mobile Network Code.
    class Carrier < Base
      field :name, :mcc, :mnc
    end

    # Ownership information for the IP address. The type classifies the kind
    # of company ("business", "education", "government", "hosting", or "isp").
    class Company < Base
      field :name, :domain, :type
    end

    # Network connection information for the IP address. The ASN is the
    # Autonomous System Number (nil when unknown), and the type classifies
    # the network ("business", "education", "government", "hosting",
    # "inactive", or "isp"). The +anycast?+ predicate reports whether the IP
    # address is announced via anycast, i.e. simultaneously from multiple
    # locations.
    class Connection < Base
      field :asn, :domain, :organization, :route, :type
      flag :anycast, key: "is_anycast"
    end

    # Prefix and suffix applied around a formatted monetary value (for example
    # the currency symbol and a sign).
    class CurrencyFormatAffix < Base
      field :prefix, :suffix
    end

    # How monetary values are formatted for a currency.
    class CurrencyFormat < Base
      field :decimal_separator, :group_separator

      embeds :negative, :CurrencyFormatAffix
      embeds :positive, :CurrencyFormatAffix
    end

    # Currency information for the IP address location.
    class Currency < Base
      field :code, :name, :name_native, :plural, :plural_native,
            :symbol, :symbol_native

      embeds :format, :CurrencyFormat
    end

    # Threat-intelligence flags for the IP address.
    class Security < Base
      flag :abuser, key: "is_abuser"
      flag :attacker, key: "is_attacker"
      flag :bogon, key: "is_bogon"
      flag :cloud_provider, key: "is_cloud_provider"
      flag :proxy, key: "is_proxy"
      flag :relay, key: "is_relay"
      flag :tor, key: "is_tor"
      flag :tor_exit, key: "is_tor_exit"
      flag :anonymous, key: "is_anonymous"
      flag :threat, key: "is_threat"
      flag :vpn, key: "is_vpn"
    end

    # Time zone information for the IP address location. The offset is the
    # current offset from UTC in seconds.
    class TimeZone < Base
      field :id, :abbreviation, :current_time, :name, :offset

      flag :in_daylight_saving
    end

    # The comprehensive set of information associated with an IP address
    # returned by the Ipregistry API.
    #
    # Nested objects (carrier, company, connection, currency, location,
    # security, and time_zone) are always present, so chained access never
    # raises even when the API omitted them; absent fields return nil.
    class IpInfo < Base
      # ip is the IP address the data refers to; type is the IP version
      # ("IPv4" or "IPv6"); hostname is the reverse-DNS hostname, when
      # hostname resolution is requested and available.
      field :ip, :type, :hostname

      embeds :carrier, :Carrier
      embeds :company, :Company
      embeds :connection, :Connection
      embeds :currency, :Currency
      embeds :location, :Location
      embeds :security, :Security
      embeds :time_zone, :TimeZone

      def ipv4? = @data["type"] == "IPv4"

      def ipv6? = @data["type"] == "IPv6"
    end

    # IpInfo enriched with parsed User-Agent data. Returned by
    # {Client#lookup_origin}, where the User-Agent of the calling client is
    # known.
    class RequesterIpInfo < IpInfo
      # The parsed User-Agent of the requester, or nil when the API did not
      # return any.
      # @return [UserAgent, nil]
      def user_agent
        value = @data["user_agent"]
        return nil unless value.is_a?(Hash)

        @embedded ||= {}
        @embedded[:user_agent] ||= UserAgent.new(value)
      end
    end
  end
end
