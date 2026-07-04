# frozen_string_literal: true

require "ipregistry"
require "webmock/rspec"

require_relative "support/fixtures"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  # System specs (spec/system) exercise the live Ipregistry API. They are run
  # separately with `rake system` and need real network access; everything
  # else runs offline against WebMock stubs.
  config.around(:each, :system) do |example|
    WebMock.allow_net_connect!
    example.run
  ensure
    WebMock.disable_net_connect!
  end
end
