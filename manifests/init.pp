class zfs_auto_snapshot(
  $hourly_snaps = $zfs_auto_snapshot::params::hourly_snaps,
  $daily_snaps  = $zfs_auto_snapshot::params::daily_snaps,
  $weekly_snaps = $zfs_auto_snapshot::params::weekly_snaps,
  $fs_names     = $zfs_auto_snapshot::params::fs_names,
)
inherits zfs_auto_snapshot::params {

  class {'zfs_auto_snapshot::cron':
    hourly_snaps => $hourly_snaps,
    daily_snaps  => $daily_snaps,
    weekly_snaps => $weekly_snaps,
    fs_names     => $fs_names,
  }

  # Installs to /usr/local/sbin.which we can assume exists as per the Filesystem Hierachy Standard

  file { '/usr/local/sbin/zfs-auto-snapshot' :
    ensure => present,
    source => "puppet:///modules/${module_name}/zfs-auto-snapshot.pl",
    owner => 'root', group => 'root', mode => 0755,
  }
}
