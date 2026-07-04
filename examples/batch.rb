# frozen_string_literal: true

# Looks up several IP addresses in a single batch request. Each entry may
# independently succeed or fail (for example on an invalid address).
#
# Usage: IPREGISTRY_API_KEY=YOUR_API_KEY ruby examples/batch.rb

require_relative "../lib/ipregistry"

client = Ipregistry::Client.new(ENV.fetch("IPREGISTRY_API_KEY"))

response = client.batch_lookup(["73.2.2.2", "8.8.8.8", "2001:67c:2e8:22::c100:68b", "not-an-ip"])

response.each do |result|
  if result.success?
    info = result.value
    puts "#{info.ip}: #{info.location.country.name} (#{info.connection.organization})"
  else
    puts "entry failed: #{result.error.message} [#{result.error.code}]"
  end
end
