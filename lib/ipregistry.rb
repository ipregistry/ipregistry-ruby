# frozen_string_literal: true

require_relative "ipregistry/version"
require_relative "ipregistry/errors"
require_relative "ipregistry/cache"
require_relative "ipregistry/models/base"
require_relative "ipregistry/models/location"
require_relative "ipregistry/models/ip_info"
require_relative "ipregistry/models/user_agent"
require_relative "ipregistry/batch_response"
require_relative "ipregistry/client"

# Official Ruby client for the Ipregistry API (https://ipregistry.co), a fast
# and reliable IP geolocation and threat data service.
#
#   client = Ipregistry::Client.new("YOUR_API_KEY")
#   info = client.lookup("8.8.8.8")
#   info.location.country.name # => "United States"
#   info.security.vpn?         # => false
module Ipregistry
  # Reports whether the given raw User-Agent string looks like a crawler or
  # bot. It is a lightweight heuristic — useful for skipping IP lookups on
  # automated traffic — that matches the substrings "bot", "spider", and
  # "slurp" case-insensitively.
  #
  #   unless Ipregistry.bot?(request.user_agent)
  #     info = client.lookup(request.remote_ip)
  #   end
  def self.bot?(user_agent)
    value = user_agent.to_s.downcase
    value.include?("bot") || value.include?("spider") || value.include?("slurp")
  end
end
