# frozen_string_literal: true

# Response payloads mirroring the Ipregistry API, shared across specs.
module Fixtures
  module_function

  def ip_payload(ip = "8.8.8.8")
    {
      "ip" => ip,
      "type" => "IPv4",
      "hostname" => "dns.google",
      "carrier" => { "name" => "T-Mobile", "mcc" => "310", "mnc" => "160" },
      "company" => { "domain" => "google.com", "name" => "Google LLC", "type" => "business" },
      "connection" => {
        "asn" => 15_169,
        "domain" => "google.com",
        "is_anycast" => true,
        "organization" => "Google LLC",
        "route" => "8.8.8.0/24",
        "type" => "business"
      },
      "currency" => {
        "code" => "USD",
        "name" => "US Dollar",
        "name_native" => "US Dollar",
        "plural" => "US dollars",
        "plural_native" => "US dollars",
        "symbol" => "$",
        "symbol_native" => "$",
        "format" => {
          "decimal_separator" => ".",
          "group_separator" => ",",
          "negative" => { "prefix" => "-$", "suffix" => "" },
          "positive" => { "prefix" => "$", "suffix" => "" }
        }
      },
      "location" => {
        "continent" => { "code" => "NA", "name" => "North America" },
        "country" => {
          "area" => 9_629_091.0,
          "borders" => %w[CA MX],
          "calling_code" => "1",
          "capital" => "Washington D.C.",
          "code" => "US",
          "name" => "United States",
          "population" => 331_002_651,
          "population_density" => 34.37,
          "flag" => {
            "emoji" => "🇺🇸",
            "emoji_unicode" => "U+1F1FA U+1F1F8",
            "emojitwo" => "https://cdn.ipregistry.co/flags/emojitwo/us.svg",
            "noto" => "https://cdn.ipregistry.co/flags/noto/us.png",
            "twemoji" => "https://cdn.ipregistry.co/flags/twemoji/us.svg",
            "wikimedia" => "https://cdn.ipregistry.co/flags/wikimedia/us.svg"
          },
          "languages" => [{ "code" => "en", "name" => "English", "native" => "English" }],
          "tld" => ".us"
        },
        "region" => { "code" => "US-CA", "name" => "California" },
        "city" => "Mountain View",
        "postal" => "94043",
        "latitude" => 37.40599,
        "longitude" => -122.078514,
        "language" => { "code" => "en", "name" => "English", "native" => "English" },
        "in_eu" => false
      },
      "security" => {
        "is_abuser" => false,
        "is_attacker" => false,
        "is_bogon" => false,
        "is_cloud_provider" => true,
        "is_proxy" => false,
        "is_residential_proxy" => false,
        "is_relay" => false,
        "is_tor" => false,
        "is_tor_exit" => false,
        "is_anonymous" => false,
        "is_threat" => false,
        "is_vpn" => false
      },
      "time_zone" => {
        "id" => "America/Los_Angeles",
        "abbreviation" => "PDT",
        "current_time" => "2026-07-04T10:00:00-07:00",
        "name" => "Pacific Daylight Time",
        "offset" => -25_200,
        "in_daylight_saving" => true
      }
    }
  end

  def user_agent_payload
    {
      "header" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/120.0",
      "name" => "Chrome",
      "type" => "browser",
      "version" => "120.0",
      "version_major" => "120",
      "device" => { "brand" => "Apple", "name" => "Mac", "type" => "desktop" },
      "engine" => { "name" => "Blink", "type" => "browser", "version" => "120.0", "version_major" => "120" },
      "os" => { "name" => "macOS", "type" => "desktop", "version" => "10.15.7" }
    }
  end

  def error_payload(code, message: "something went wrong", resolution: "fix it")
    { "code" => code, "message" => message, "resolution" => resolution }
  end
end
