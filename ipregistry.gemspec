# frozen_string_literal: true

require_relative "lib/ipregistry/version"

Gem::Specification.new do |spec|
  spec.name = "ipregistry"
  spec.version = Ipregistry::VERSION
  spec.authors = ["Ipregistry"]
  spec.email = ["support@ipregistry.co"]

  spec.summary = "Official Ruby client for the Ipregistry IP geolocation and threat data API"
  spec.description = "Look up IP addresses (single, batch, or the requester's own) and parse User-Agent " \
                     "strings with the Ipregistry API. Returns carrier, company, connection, currency, " \
                     "location, time zone, and threat data. Zero runtime dependencies, optional in-memory " \
                     "caching, and automatic retries with exponential backoff."
  spec.homepage = "https://github.com/ipregistry/ipregistry-ruby"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "documentation_uri" => "https://ipregistry.co/docs",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "LICENSE", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]
end
