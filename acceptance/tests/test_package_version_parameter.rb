require 'beaker-puppet'
require_relative '../helpers'

# Attempts to find the previous semver-based relase of the given agent version
def some_prevous_version(version)
  parts = version.to_s.split('.').map(&:to_i)
  raise "Unexpected non-semver format for version '#{version}'; cannot decrement it" unless parts.length == 3
  i = 2
  while (i > -1) && (parts[i] == 0)
    i -= 1
  end
  parts[i] = parts[i] - 1
  parts.join('.')
end

test_name 'puppet_agent class: package_version parameter' do
  teardown { run_teardown }

  run_setup()

  agents_only.each do |agent|
    other_agent_version = ENV['TO_AGENT_VERSION'] ||
                          some_prevous_version(puppet_agent_version_on(agent))
    class_manifest = %(class { 'puppet_agent': package_version => '#{other_agent_version}' })

    step "Apply the puppet_agent class to install another version (#{other_agent_version}) of puppet-agent" do
      apply_manifest_on(agent, class_manifest, catch_failures: true)
    end

    step 'Confirm that the install succeeded' do
      assert_equal(other_agent_version, puppet_agent_version_on(agent))
    end

    step 'Apply the original manifest again' do
      apply_manifest_on(agent, class_manifest, catch_failures: true)
    end

    step 'Confirm that the process was idempotent' do
      assert_equal(other_agent_version, puppet_agent_version_on(agent))
    end
  end
end
