require 'beaker-puppet'

SUPPORTING_FILES = File.expand_path('./files')

module Beaker
  module DSL
   module Roles
      # @return [Array<Host>] Hosts with the agent role, except for the master. May be empty.
      def agents_only
        hosts_as(:agent).select do |host|
          !host['roles'].include?('master')
        end.to_a
      end
    end
  end
end

# Gather arguments for `install_puppet_agent_on` based on the environment, sanity check, and format them.
# @return [Hash] An options hash to pass to BeakerPuppet's `install_puppet_agent_on` method
def agent_install_options
  agent_version = ENV['FROM_AGENT_VERSION'] || ENV['PUPPET_CLIENT_VERSION'] # This is the legacy name from puppet 3 / module 1.x

  if agent_version
    unless dev_builds_accessible?
      # The user requested a specific build, but they can't download from internal sources
      env_var_name = ENV['FROM_AGENT_VERSION'] ? 'FROM_AGENT_VERSION' : 'PUPPET_CLIENT_VERSION'
      fail_test(<<-WHY
  You requested a specific build of puppet-agent, but you don't have access to
  Puppet's internal build servers. You can either:

  - Unset the #{env_var_name} environment variable to accept the latest Puppet 4
    agent release (this is the defualt), or
  - Set the $FROM_PUPPET_COLLECTION environment variable to 'puppet5' or 'puppet6' to
    use the latest releases from those streams.

  WHY
      )
    end

    return { puppet_agent_version: agent_version }
  end

  { puppet_collection: (ENV['FROM_PUPPET_COLLECTION'] || 'pc1').downcase }
end

# Installs the puppet_agent module on the target host, and then uses the PMT to install puppet_agent's dependencies
def install_modules_on(host)
  install_dev_puppet_module_on(host, {
    source: File.join(File.dirname(__FILE__), '..', ),
    module_name: 'puppet_agent'
  })

  on(host, puppet('module', 'install', 'puppetlabs-stdlib',     '--version', '4.16.0'), { acceptable_exit_codes: [0] })
  on(host, puppet('module', 'install', 'puppetlabs-inifile',    '--version', '2.1.0'),  { acceptable_exit_codes: [0] })
  on(host, puppet('module', 'install', 'puppetlabs-apt',        '--version', '4.4.0'),  { acceptable_exit_codes: [0] })
  on(host, puppet('module', 'install', 'puppetlabs-transition', '--version', '0.1.1'),  { acceptable_exit_codes: [0] })
end

# Pass these options to any `with_puppet_running_on` block
def master_puppetconf
  {
      master: { autosign: true, dns_alt_names: master }
  }
end

# These options are used to configure puppet-agent
def agent_puppetconf
  {
      agent: { # TODO: change to main?
          server: "#{master}",
          ssldir: "$vardir/ssl"  # Necessary?
      }
  }
end

def run_setup(use_master: false)
  logger.notify("Setup: Install puppet-agent on agents")

  # Install the puppet-agent package and configure it
  agents_only.each do |agent|
    install_puppet_agent_on(agent, agent_install_options)
    configure_puppet_on(agent, agent_puppetconf)
  end

  # Either install modules or clear SSL/firewall, based on whether this is a masterless run:
  if use_master
    logger.notify("Setup [master/agent test]: Clean SSL and disable firewall on all hosts")
    hosts.each do |host|
      on(host, "rm -rf '#{host.puppet['ssldir']}'")
      stop_firewall_with_puppet_on(host)
    end
  else
    # If we're not using a master, the agent will need to have the puppet_agent module installed:
    logger.notify("Setup [masterless test]: Install puppet_agent module on agents")
    agents_only.each do |agent|
      install_modules_on(agent)
    end
  end
end

def run_teardown
  logger.notify("Teardown: Purge puppet from agents")

  agents_only.each do |host|
    if host['platform'] =~ /windows/
      scp_to(host, "#{SUPPORTING_FILES}/uninstall.ps1", "uninstall.ps1")
      on(host, 'rm -rf C:/ProgramData/PuppetLabs')
      on(host, 'powershell.exe -File uninstall.ps1 < /dev/null')
    else
      manifest_lines = []
      # Remove pc_repo
      # ---
      # Note pc_repo is specific to this module's manifests. This is knowledge we need to clean from the machine after each run.
      case host['platform']
      when /debian|ubuntu/
        on(host, '/opt/puppetlabs/bin/puppet module install puppetlabs-apt --version 4.4.0', {acceptable_exit_codes: [0, 1]})
        manifest_lines << "include apt"
        manifest_lines << "apt::source { 'pc_repo': ensure => absent, notify => Package['puppet-agent'] }"
      when /fedora|el|centos/
        manifest_lines << "yumrepo { 'pc_repo': ensure => absent, notify => Package['puppet-agent'] }"
      else
        logger.info("Not sure how to remove a pc_repo repo on #{host['platform']}; skipping that part")
      end

      manifest_lines << "file { ['/etc/puppet', '/etc/puppetlabs', '/etc/mcollective']: ensure => absent, force => true, backup => false }"
      manifest_lines << "package { ['puppet-agent']: ensure => purged }"

      on(host, puppet('apply', '-e', %("#{manifest_lines.join("\n")}"), '--no-report'), {acceptable_exit_codes: [0, 1]})
    end
  end
end
