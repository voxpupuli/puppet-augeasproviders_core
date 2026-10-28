# frozen_string_literal: true

require 'spec_helper_acceptance'

# augeasproviders_core only ships a library, so exercise it through a minimal
# shell variable type and provider built on it, installed as its own module.
TEST_TYPE = <<~RUBY
  Puppet::Type.newtype(:augeasproviders_core_test) do
    @doc = 'Manages a shell variable in a file (acceptance test fixture)'

    ensurable

    newparam(:name, namevar: true)
    newproperty(:value)
    newparam(:target)
  end

  Puppet::Type.type(:augeasproviders_core_test).provide(:augeas, parent: Puppet::Type.type(:augeasprovider).provider(:default)) do
    default_file { '/etc/augeasproviders_core_test.conf' }

    lens { 'Shellvars.lns' }

    resource_path do |resource|
      "$target/\#{resource[:name]}"
    end

    confine feature: :augeas

    def self.instances
      augopen do |aug|
        aug.match("$target/*[label() != '#comment']").map do |path|
          new(name: path_label(aug, path), ensure: :present, value: unquoteit(aug.get(path)))
        end
      end
    end

    def create
      augopen! do |aug|
        aug.set(resource_path, quoteit(resource[:value]))
      end
    end

    def value
      augopen do |aug|
        unquoteit(aug.get('$resource'))
      end
    end

    def value=(value)
      augopen! do |aug|
        aug.set('$resource', quoteit(value, aug.get('$resource')))
      end
    end
  end
RUBY

describe 'augeasprovider' do
  before(:all) do
    type_dir = '/etc/puppetlabs/code/environments/production/modules/augeasproviders_core_test/lib/puppet/type'
    on(default, "mkdir -p #{type_dir}")
    create_remote_file(default, "#{type_dir}/augeasproviders_core_test.rb", TEST_TYPE)
  end

  context 'when creating entries in a new file' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<~PUPPET
          augeasproviders_core_test { 'FOO':
            value => 'bar',
          }
          augeasproviders_core_test { 'GREETING':
            value => 'hello world',
          }
        PUPPET
      end
    end

    describe file('/etc/augeasproviders_core_test.conf') do
      its(:content) { is_expected.to eq(%(FOO=bar\nGREETING="hello world"\n)) }
    end
  end

  context 'when updating an existing file' do
    before(:all) do
      create_remote_file(default, '/etc/augeasproviders_core_test.conf', <<~CONF)
        # keep this comment
        FOO=bar
        QUOTED='old'
      CONF
    end

    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<~PUPPET
          augeasproviders_core_test { 'FOO':
            value => 'baz',
          }
          augeasproviders_core_test { 'QUOTED':
            value => 'new',
          }
        PUPPET
      end
    end

    describe file('/etc/augeasproviders_core_test.conf') do
      its(:content) { is_expected.to eq(%(# keep this comment\nFOO=baz\nQUOTED='new'\n)) }
    end
  end

  context 'when listing entries with puppet resource' do
    it 'returns the existing entries' do
      output = on(default, 'puppet resource augeasproviders_core_test').stdout
      expect(output).to eq(<<~PUPPET)
        augeasproviders_core_test { 'FOO':
          ensure   => 'present',
          provider => 'augeas',
          value    => 'baz',
        }
        augeasproviders_core_test { 'QUOTED':
          ensure   => 'present',
          provider => 'augeas',
          value    => 'new',
        }
      PUPPET
    end
  end

  context 'when removing an entry' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<~PUPPET
          augeasproviders_core_test { 'FOO':
            ensure => absent,
          }
        PUPPET
      end
    end

    describe file('/etc/augeasproviders_core_test.conf') do
      its(:content) { is_expected.to eq(%(# keep this comment\nQUOTED='new'\n)) }
    end
  end

  context 'when using a custom target' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<~PUPPET
          augeasproviders_core_test { 'CUSTOM':
            value  => 'yes',
            target => '/tmp/augeasproviders_core_test_custom.conf',
          }
        PUPPET
      end
    end

    describe file('/tmp/augeasproviders_core_test_custom.conf') do
      its(:content) { is_expected.to eq("CUSTOM=yes\n") }
    end
  end
end
