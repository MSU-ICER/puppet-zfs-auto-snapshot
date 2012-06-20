class zfs_auto_snapshot {
  include zfs_auto_snapshot::cron
# Below needed only if we're putting it in /usr/local.
  /*
  file { '/usr/local/zfs-auto-snapshot' :
    ensure => directory,
    owner => 'root', group => 'root', mode => 0755,
  }
  file { '/usr/local/zfs-auto-snapshot/sbin' :
    ensure => directory,
    owner => 'root', group => 'root', mode => 0755,
  }
  */
# Going with /usr/sbin instead as OmniOS is quite minimal.
# Chance of a collision is quite low.
  file { '/usr/sbin/zfs-auto-snapshot' :
    ensure => present,
    source => "puppet:///modules/${module_name}/zfs-auto-snapshot.pl",
    owner => 'root', group => 'root', mode => 0755,
  }
}
