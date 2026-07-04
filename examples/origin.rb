# frozen_string_literal: true

# Looks up the IP address the request originates from, including parsed
# User-Agent data.
#
# Usage: IPREGISTRY_API_KEY=YOUR_API_KEY ruby examples/origin.rb

require_relative "../lib/ipregistry"

client = Ipregistry::Client.new(ENV.fetch("IPREGISTRY_API_KEY"))

origin = client.lookup_origin

puts "Your IP:  #{origin.ip}"
puts "Country:  #{origin.location.country.name}"
puts "City:     #{origin.location.city}"
puts "Browser:  #{origin.user_agent&.name}"
puts "OS:       #{origin.user_agent&.operating_system&.name}"
