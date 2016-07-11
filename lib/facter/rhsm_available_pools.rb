#!/usr/bin/ruby
#
#  Report the pools (F/OSS repos) available to this system
#  This will be empty if the registration is bad.
#
#   Copyright 2016 Pat Riehecky <riehecky@fnal.gov>
#
#   See LICENSE for licensing.
#
begin
    require 'facter/util/facter_cacheable'
  rescue LoadError => e
    Facter.debug("#{e.backtrace[0]}: #{$!}.")
end

module Facter::Util::Rhsm_available_pools
  @doc=<<EOF
  Available Subscription Pools for this client.
EOF
  class << self
    def get_output(input)
      lines = []
      input.split("\n").each { |line|
        if line =~ /Pool ID:\s+(.+)$/
          lines.push($1.chomp)
          next
        end
      }
      lines
    end
    def rhsm_available_pools
      value = []
      begin
        available = Facter::Util::Resolution.exec(
          '/usr/sbin/subscription-manager list --available')
        value = get_output(available)
      rescue Exception => e
          Facter.debug("#{e.backtrace[0]}: #{$!}.") unless $! =~ /This system is not yet registered/
      end
      value
    end
  end
end

if File.exist? '/usr/sbin/subscription-manager'
  if Puppet.features.facter_cacheable?
    Facter.add(:rhsm_available_pools) do
      setcode do
        # TODO: use another fact to set the TTL in userspace
        # right now this can be done by removing the cache files
        cache = Facter::Util::Facter_cacheable.cached?(:rhsm_available_pools, 24 * 3600)
        if ! cache
          repos = Facter::Util::Rhsm_available_pools.rhsm_available_pools
          Facter::Util::Facter_cacheable.cache(:rhsm_available_pools, repos)
          repos
        else
          if cache.is_a? Array
            cache
          else
            cache["rhsm_available_pools"]
          end
        end
      end
    end
  else
    Facter.add(:rhsm_available_pools) do
      setcode { Facter::Util::Rhsm_available_pools.rhsm_available_pools }
    end
  end
end
