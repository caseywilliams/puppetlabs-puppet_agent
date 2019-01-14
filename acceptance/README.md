# Acceptance tests for puppetlabs-puppet_agent

## Background

### About Beaker

Beaker is a host provisioning and an acceptance testing framework. If you are
unfamiliar with beaker, you can start with these documents:

- [The Beaker DSL document](https://github.com/puppetlabs/beaker/blob/master/docs/how_to/the_beaker_dsl.md) will help you understand the test code in the `tests/` and `pre_suite/` subdirectories.
- [The Beaker Style Guide](https://github.com/puppetlabs/beaker/blob/master/docs/concepts/style_guide.md) will help you write new test code.
- [Argument Processing](https://github.com/puppetlabs/beaker/blob/master/docs/concepts/argument_processing_and_precedence.md) and [Using Subcommands](https://github.com/puppetlabs/beaker/blob/master/docs/tutorials/subcommands.md) have more information on beaker's command line and environmental options.

### About these tests

This module is responsible for upgrading puppet-agent. Testing this behavior
necessarily involves repeatedly installing and uninstalling puppet-agent.
Ideally, the test hosts would be totally destroyed and reprovisioned before each
fresh install of puppet-agent, but beaker does not support workflows like this.
Instead:

- The `run_setup` helper installs puppet-agent, plus this module and its dependencies.
- The `run_teardown` helper uninstalls puppet-agent and removes the modules.

The `run_foss_upgrade_with_params` helper uses `run_setup` to install agents at
an initial version, calls `run_teardown`, performs an upgrade using the
puppet_agent class and a given set of params, and allows for making assertions
about the upgraded hosts in a block.

See [`helpers.rb`](./helpers.rb) for more.

## How to run the tests

### Install the dependencies

This directory has its own Gemfile, containing gems required only for these
acceptance tests. Ensure that you have [bundler](https://bundler.io/) installed,
and then use it to install the dependencies:

```sh
bundle install --path .bundle
```

This will install [`beaker`](https://github.com/puppetlabs/beaker) and
[`beaker-puppet`](https://github.com/puppetlabs/beaker-puppet) (a beaker
library for working with puppet specifically), plus several hypervisor gems
for working with beaker and vagrant, docker, or vsphere.

### Set up the test hosts

Before running any of the acceptance tests in the `tests/` directory, you must
do the following once:

- configure beaker,
- provision VMs or containers as test hosts, and
- run the setup tasks in the `pre_suite/` directory.

Here's how:

```sh
# Use `beaker-hostgenerator` generate a hosts file that describes the
# types of hosts you want to test. See beaker-hostgenerator's help for more
# information on available host types and roles.
# This example creates a Centos 7 master and a single Debian 9 agent, which will be provisioned with Docker.
bundle exec beaker-hostgenerator -t docker centos7-64mcda-debian9-64a > ./hosts.yaml

# Now run `beaker init` to generate configuration for this beaker run in
# `.beaker/`. Pass it the location of your hosts file and the options file:
bundle exec beaker init -h ./hosts.yaml -o options.rb

# Create the VMs or containers that will act as the test hosts:
bundle exec beaker provision

# Now run the pre-suite setup tasks. This will install puppetserver and the
# puppet_agent module on your master host in preparation for running the tests:
bundle exec beaker exec pre-suite
```

### Run and re-run the tests

Once you've set up beaker, you can run any number of tests any number of times:

```sh
# Run all the tests
bundle exec beaker exec
# Run all the tests in a specific directory
bundle exec beaker exec ./tests/subdir
# Run a commma-separated list of specific tests:
bundle exec beaker exec ./path/to/test.rb,./another/test.rb
```

### Clean up

You can destroy existing test hosts like this:

```sh
bundle exec beaker destroy
```
