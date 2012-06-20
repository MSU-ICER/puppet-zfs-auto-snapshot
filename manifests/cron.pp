class zfs_auto_snapshot::cron {
  $fsname = [ 'localpool' ]
  cron { 'zfssnap_hourly': 
    command  => "/usr/sbin/zfs-auto-snapshot --syslog --label hourly --keep 24 --recursive $fsname",
    user     => 'root',
    minute   => 0,
  }
  cron { 'zfssnap_daily': 
    command  => "/usr/sbin/zfs-auto-snapshot --syslog --label daily --keep 7 --recursive $fsname",
    user     => 'root',
    minute   => 0,
    hour     => 0,
  }
  cron { 'zfssnap_weekly': 
    command  => "/usr/sbin/zfs-auto-snapshot --syslog --label weekly --keep 4 --recursive $fsname",
    user     => 'root',
    minute   => 0,
    hour     => 0,
    monthday => 1,
  }

}
