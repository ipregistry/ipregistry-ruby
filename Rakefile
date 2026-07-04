# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

desc "Run unit and behavior specs (offline, no API key required)"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.exclude_pattern = "spec/system/**/*_spec.rb"
end

desc "Run system specs against the live Ipregistry API (requires IPREGISTRY_API_KEY)"
RSpec::Core::RakeTask.new(:system) do |t|
  t.pattern = "spec/system/**/*_spec.rb"
end

RuboCop::RakeTask.new

task default: %i[rubocop spec]
