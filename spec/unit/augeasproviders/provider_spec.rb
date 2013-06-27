#!/usr/bin/env rspec

require 'spec_helper'
require 'augeasproviders/provider'

klass = AugeasProviders::Provider

describe klass do
  include klass

  let(:tmptarget) { aug_fixture("full") }
  let(:thetarget) { tmptarget.path }

  it "should print /augeas//error on save" do
    # Prepare an invalid save
    lens { 'Hosts.lns' }
    default_file { thetarget }
    aug = augopen
    aug.rm("/files#{thetarget}/*/ipaddr").should_not == 0

    lambda { augsave!(aug) }.should raise_error Augeas::Error, /message = Failed to match/
  end
end
