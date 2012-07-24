class zfs_auto_snapshot::cron {
  cron { 'zfssnap_hourly': 
    command  => "/usr/sbin/zfs-auto-snapshot --syslog --label hourly --keep $zfs_auto_snapshot::params::hourly_snaps --recursive $zfs_auto_snapshot::params::$fsname",
    user     => 'root',
    minute   => 0,
  }
  cron { 'zfssnap_daily': 
    command  => "/usr/sbin/zfs-auto-snapshot --syslog --label daily --keep $zfs_auto_snapshot::params::daily_snaps --recursive $zfs_auto_snapshot::params::$fsname",
    user     => 'root',
    minute   => 0,
    hour     => 0,
  }
  cron { 'zfssnap_weekly': 
    command  => "/usr/sbin/zfs-auto-snapshot --syslog --label weekly --keep $zfs_auto_snapshot::params::weekly_snaps --recursive $zfs_auto_snapshot::params::$fsname",
    user     => 'root',
    minute   => 0,
    hour     => 0,
    monthday => 1,
  }

}
