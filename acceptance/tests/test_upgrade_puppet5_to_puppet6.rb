require 'beaker-puppet'
require_relative '../helpers'

# Tests FOSS upgrades from the latest puppet 5 to the latest puppet 6
test_name 'puppet_agent class: package_version parameter for FOSS upgrades' do
  confine :except, platform: PE_ONLY_PLATFORMS

  expect_environment_variables('FROM_AGENT_VERSION', 'TO_AGENT_VERSION')
  teardown { run_teardown }
  run_setup

  target_version = ENV['TO_AGENT_VERSION']

  manifest_content = <<-PP
  class { 'puppet_agent': package_version => '#{target_version}' }
PP

  agents_only.each do |agent|
    with_default_site_pp(manifest_content) do
      installed_version = puppet_agent_version_on(agent)
      assert_equal(target_version, installed_version,
                   "Expected puppet-agent version '#{target_version}' to be installed on #{agent} (#{agent['platform']}), but found '#{installed_version}'")
    end
  end
end
