class zfs_auto_snapshot::params {

# Filesystem to snapshot:
# Default (specific to some MSU systems)
  $pool_names = [ 'localpool' ]

# Number of snapshots:
# Number of hourly snaps to keep:
  $hourly_snaps = 24
# Number of daily snaps to keep:
  $daily_snaps = 7
# Number of weekly snaps to keep:
  $weekly_snaps = 4
}
