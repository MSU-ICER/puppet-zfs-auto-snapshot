class zfs_auto_snapshot($pool_names) {
  include zfs_auto_snapshot::cron
# Installs to /usr/local/sbin.
  file { '/usr/local' :
    ensure => directory,
    owner => 'root', group => 'root', mode => 0755,
  }
  file { '/usr/local/sbin' :
    ensure => directory,
    owner => 'root', group => 'root', mode => 0755,
  }
  file { '/usr/local/sbin/zfs-auto-snapshot' :
    ensure => present,
    source => "puppet:///modules/${module_name}/zfs-auto-snapshot.pl",
    owner => 'root', group => 'root', mode => 0755,
  }
}
