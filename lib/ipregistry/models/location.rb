# frozen_string_literal: true

module Ipregistry
  module Models
    # Continent-level information for a location.
    class Continent < Base
      field :code, :name
    end

    # Language information.
    class Language < Base
      field :code, :name

      # The language's name in the language itself.
      def native_name
        @data["native"]
      end
    end

    # Representations of a country flag across several icon sets.
    class Flag < Base
      field :emoji, :emoji_unicode, :emojitwo, :noto, :twemoji, :wikimedia
    end

    # Country-level information for a location.
    class Country < Base
      # area is the total land area in square kilometers; borders lists the
      # ISO 3166-1 alpha-2 codes of bordering countries; code is the ISO
      # 3166-1 alpha-2 country code (for example "US"); population is the
      # estimated number of inhabitants; population_density is the number of
      # inhabitants per square kilometer; tld is the country-code top-level
      # domain (for example ".us").
      field :area, :calling_code, :capital, :code, :name,
            :population, :population_density, :tld

      embeds :flag, :Flag
      embeds_many :languages, :Language

      # ISO 3166-1 alpha-2 codes of bordering countries.
      # @return [Array<String>]
      def borders
        value = @data["borders"]
        value.is_a?(Array) ? value : []
      end
    end

    # Administrative region (state/province) information. The code is
    # typically the ISO 3166-2 subdivision code.
    class Region < Base
      field :code, :name
    end

    # Geographical location associated with an IP address.
    class Location < Base
      # city, postal, and the decimal-degree latitude/longitude (nil when
      # unavailable).
      field :city, :postal, :latitude, :longitude

      embeds :continent, :Continent
      embeds :country, :Country
      embeds :region, :Region
      # The primary language spoken at the location.
      embeds :language, :Language

      # Whether the location is within a European Union member state.
      flag :in_eu
    end
  end
end
