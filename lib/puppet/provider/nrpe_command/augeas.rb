# Alternative Augeas-based provider for nrpe type
#
# Copyright (c) 2012 Christian Kaenzig
# Licensed under the Apache License, Version 2.0

require File.dirname(__FILE__) + '/../../../augeasproviders/provider'

Puppet::Type.type(:nrpe_command).provide(:augeas) do
  desc "Uses Augeas API to update nrpe commands"

  include AugeasProviders::Provider

  default_file { '/etc/nagios/nrpe.cfg' }

  lens { 'Nrpe.lns' }

  confine :feature => :augeas

  def self.instances
    aug = nil
    file = target
    begin
      resources = []
      aug = augopen
      aug.match("/files#{file}/command/*").each do |spath|
        resource = {:ensure => :present}

        resource[:name] = spath.split("/")[-1]
        resource[:command] = aug.get("#{spath}")

        resources << new(resource)
      end
      resources
    ensure
      aug.close if aug
    end
  end

  def exists? 
    aug = nil
    begin
      aug = self.class.augopen(resource)
      not aug.match("/files#{self.class.target(resource)}/command/#{resource[:name]}").empty?
    ensure
      aug.close if aug
    end
  end

  def create 
    aug = nil
    begin
      aug = self.class.augopen(resource)
      aug.set("/files#{self.class.target(resource)}/command[last()+1]/#{resource[:name]}", resource[:command])
      augsave!(aug)
    ensure
      aug.close if aug
    end
  end

  def destroy
    aug = nil
    begin
      aug = self.class.augopen(resource)
      aug.rm("/files#{self.class.target(resource)}/command[#{resource[:name]}]")
      augsave!(aug)
    ensure
      aug.close if aug
    end
  end

  def target
    self.class.target(resource)
  end

  def command
    aug = nil
    begin
      aug = self.class.augopen(resource)
      aug.get("/files#{self.class.target(resource)}/command/#{resource[:name]}")
    ensure
      aug.close if aug
    end
  end

  def command=(value)
    aug = nil
    begin
      aug = self.class.augopen(resource)
      aug.set("/files#{self.class.target(resource)}/command/#{resource[:name]}", value)
      augsave!(aug)
    ensure
      aug.close if aug
    end
  end
end
