# == Class subscription_manager::install
#
# This class is called from subscription_manager for install.
#
class subscription_manager::install {

  # any generic passed into the model
  package { $::subscription_manager::package_names:
    ensure => present,
  }

  # support a custom repository if provided
  $_version = $::puppetversion ? {
    undef   => '', # when was puppetversion added? (see PUP-4359)
    default => $::puppetversion,
  }
  if $::subscription_manager::repo != '' and
    $::subscription_manager::repo != undef {
    if versioncmp($_version, '3.4.1') > 0 {
      contain $::subscription_manager::repo
    } else {
      include $::subscription_manager::repo
    }
    Class[ $::subscription_manager::repo ] ->
      Package[ $::subscription_manager::package_names ]
  }

  $_pkg = "katello-ca-consumer-${::subscription_manager::server_hostname}"
  # four scenarios
  # I.  never registered
  #  - no ca_name
  #  - no identity
  #  - just install normally
  package { $_pkg:
    ensure   => 'latest',
    provider => 'rpm',
    source   =>
  "http://${::subscription_manager::server_hostname}/pub/katello-ca-consumer-latest.noarch.rpm",
  }

  # II. registered to correct server
  #  - ca_name == server_hostname
  #  - identity is set
  #  - do nothing new, let puppet idempotency handle it

  # III. registered to different server
  #  - ca_name != server_hostname
  #  - identity may or may not be set
  #  - remove old, install new
  if $::rhsm_ca_name != '' and $::rhsm_ca_name != undef {
    # an SSL Certificate Authority is detected
    if $::rhsm_ca_name != $::subscription_manager::server_hostname {
      # but CA is changing
      # remove the old package
      package { "katello-ca-consumer-${::rhsm_ca_name}": ensure => 'absent', }
      Package["katello-ca-consumer-${::rhsm_ca_name}"] -> Package[$_pkg]
    }
  }

  # IV. registered to same server but CA is bad
  #  - ca_name == server_hostname
  #  - identity is not set
  #  - reinstall (this requires a pupetlabs-transition)
  # This case is meant to prevent extra regitrations on pre-6.2 Satellite
  if ((($::rhsm_identity == '' or $::rhsm_identity == undef) and
    $::rhsm_ca_name == $::subscription_manager::server_hostname) or
    ($::rhsm_ca_name == $::subscription_manager::server_hostname and
    $::subscription_manager::force == true )) {
    $_attributes = {
      'ensure'          => 'absent',
      'provider'        => 'rpm',
      'install_options' => [ '--force', '--nodeps' ],
    }
    transition {'purge-bad-rhsm_ca-package':
      resource   => Package[$_pkg],
      attributes => $_attributes,
      prior_to   => Package[$_pkg],
    }
  }

}
