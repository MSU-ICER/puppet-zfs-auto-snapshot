class zfs-auto-snapshot::params {

# Filesystem to snapshot:
# Default (specific to some MSU systems)
  $fsname = $pool_names

# Number of snapshots:
# Number of hourly snaps to keep:
  $hourly_snaps = 24
# Number of daily snaps to keep:
  $daily_snaps = 7
# Number of weekly snaps to keep:
  $weekly_snaps = 4
}
