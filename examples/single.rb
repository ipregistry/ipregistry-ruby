# frozen_string_literal: true

# Looks up a single IP address.
#
# Usage: IPREGISTRY_API_KEY=YOUR_API_KEY ruby examples/single.rb [ip]

require_relative "../lib/ipregistry"

client = Ipregistry::Client.new(ENV.fetch("IPREGISTRY_API_KEY"))

info = client.lookup(ARGV.fetch(0, "8.8.8.8"))

puts "IP:        #{info.ip} (#{info.type})"
puts "Country:   #{info.location.country.name} #{info.location.country.flag.emoji}"
puts "City:      #{info.location.city}"
puts "Company:   #{info.company.name}"
puts "ASN:       #{info.connection.asn} (#{info.connection.organization})"
puts "Time zone: #{info.time_zone.id} (#{info.time_zone.current_time})"
puts "VPN:       #{info.security.vpn?}"
puts "Threat:    #{info.security.threat?}"
