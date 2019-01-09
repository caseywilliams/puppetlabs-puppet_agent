require 'spec_helper'

describe 'puppet_agent::params' do
  facts = {
    osfamily: 'Debian'
  }

  # rspec-puppet lets us query the compiled catalog only, so we can only check
  # if any specific resources have been declared. We cannot query for class
  # variables, so we cannot query for the collection variable's value. But we
  # can use a workaround by creating a notify resource whose message contains
  # the value and query that instead since it will be added as part of the
  # catalog. notify_resource tells rspec-puppet to include this resource only
  # after our class has been compiled, which is what we want.
  let(:notify_title) { "check puppet_agent::params::collection's value" }
  let(:post_condition) do
    <<-NOTIFY_RESOURCE
notify { "#{notify_title}":
  message => "${::puppet_agent::params::collection}"
}
    NOTIFY_RESOURCE
  end

  def sets_collection_to(collection)
    is_expected.to contain_notify(notify_title).with_message(collection)
  end

  context 'with a puppet-agent package from the 1.y.z series (contains puppet 4)' do
    let(:facts) {
      facts.merge(
        aio_agent_version: '1.10.14'
      )
    }
    it { sets_collection_to('PC1') }
  end

  context 'with a puppet-agent package from the 5.y.z series (contains puppet 5)' do
    let(:facts) {
      facts.merge(
          aio_agent_version: '5.5.9'
      )
    }
    it { sets_collection_to('puppet5') }
  end

  context 'with a pre-release package of puppet 6 (contains puppet 6)' do
    let(:facts) {
      facts.merge(
        aio_agent_version: '5.99.0'
      )
    }
    it { sets_collection_to('puppet6') }
  end

  context 'with a puppet-agent package from the 6.y.z series (contains puppet 6)' do
    let(:facts) {
      facts.merge(
        aio_agent_version: '6.0.2'
      )
    }
    it { sets_collection_to('puppet6') }
  end
end
