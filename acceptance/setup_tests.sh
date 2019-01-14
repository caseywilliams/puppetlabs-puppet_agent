export FROM_AGENT_VERSION=6.0.1
export TO_AGENT_VERSION=6.0.2
bundle install
bundle exec beaker init -h ./hosts.yaml -o ./options.rb
bundle exec beaker provision
bundle exec beaker exec ./pre_suite
