require 'beaker-puppet'
require_relative '../helpers'

# Tests FOSS upgrades from the latest puppet 4 to the latest puppet 5
test_name 'puppet_agent class: package_version parameter for FOSS upgrades' do
  confine :except, platform: PE_ONLY_PLATFORMS

  run_foss_upgrade_with_params('PC1', { collection: 'puppet5' }) do |agent|
    installed_version = puppet_agent_version_on(agent)
    assert_match(/5\.\d\.\d/, installed_version,
                 "Expected puppet-agent 5.y.z to be installed on #{agent} (#{agent['platform']}), but found '#{installed_version}'")
  end
end
