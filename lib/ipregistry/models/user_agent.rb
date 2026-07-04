# frozen_string_literal: true

module Ipregistry
  module Models
    # Device data parsed from a User-Agent string.
    class UserAgentDevice < Base
      field :brand, :name, :type
    end

    # Layout-engine data parsed from a User-Agent string.
    class UserAgentEngine < Base
      field :name, :type, :version, :version_major
    end

    # Operating-system data parsed from a User-Agent string.
    class UserAgentOperatingSystem < Base
      field :name, :type, :version
    end

    # Structured data parsed from a raw User-Agent string. The header field
    # is the raw User-Agent string that was parsed.
    class UserAgent < Base
      field :header, :name, :type, :version, :version_major

      embeds :device, :UserAgentDevice
      embeds :engine, :UserAgentEngine
      embeds :operating_system, :UserAgentOperatingSystem, key: "os"
      alias os operating_system
    end
  end
end
