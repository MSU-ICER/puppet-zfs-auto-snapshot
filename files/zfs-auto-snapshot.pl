#!/usr/bin/perl

# zfs-auto-snapshot for Linux
# Automatically create, rotate, and destroy periodic ZFS snapshots.
# Copyright 2012 Tim Brody <tdb2@ecs.soton.ac.uk>
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307  USA
#

our $ZFS="/sbin/zfs";
our $ZPOOL="/sbin/zpool";

use Getopt::Long;

use strict;
use warnings;

use constant {
	ZPOOL_OFFLINE => 0,
	ZPOOL_ONLINE => 1,
	ZPOOL_SCRUBBING => 2,
};
use constant {
	warning => "daemon.warning",
	error => "daemon.err",
	info => "daemon.info",
	debug => "daemon.debug",
	notice => "daemon.notice",
};
our %log_level = (
	&warning => 1,
	&error => 1,
	&info => 2,
	&debug => 3,
	&notice => 2,
);

# Switched to localtime() from gmtime() so snapshot times make sense to users
# TODO: add local or gmt as options.
my @now = localtime();

# FIXME: add 'date' as an option?
our %opt = (
	event => '-',
	verbose => 1,
	quiet => 0,
	prefix => 'zfs-auto-snap',
	label => '',
	separator => "_",
	date => sprintf("%4d-%02d-%02d-%02d%02d",
			$now[5]+1900,
			$now[4]+1,
			@now[3,2,1]
		),
);
GetOptions(\%opt,
	'default-exclude',
	'debug',
	'event=s',
	'dry-run',
	'skip-scrub',
	'help',
	'keep=i',
	'label=s',
	'prefix=s',
	'quiet+',
	'separator=s',
	'syslog|g',
	'recursive',
	'verbose+',
) or &help;

&help if $opt{help};

our $noise = $opt{verbose} - $opt{quiet};

if( $opt{event} && length($opt{event}) > 1024 )
{
	print_log(error, "The --event parameter must be less than 1025 characters.");
	exit 139;
}
if( !@ARGV )
{
	print_log(error, "The filesystem argument list is empty.");
	exit 133;
}

our %ZPOOL_STATUS = &zpool_status();
our %IS_INCLUDED = &zfs_list();
our @OLD_SNAPSHOTS = &zfs_list_snapshots();

if( grep { $_ eq '//' } @ARGV )
{
	if( @ARGV > 1 )
	{
		print_log(error, "The // must be the only argument if it is given.");
		exit 134;
	}
	# all datasets and recursive is equivalent to just recursively snapshotting
	# from the root of each pool
	if( $opt{recursive} )
	{
		@ARGV = keys %ZPOOL_STATUS;
	}
	else
	{
		@ARGV = keys %IS_INCLUDED;
	}
}

NAME: foreach my $name (sort @ARGV)
{
	if( !exists $IS_INCLUDED{$name} )
	{
		print_log(error, "$name is not a ZFS filesystem or volume.");
		next NAME;
	}

	# disabled by com.sun:auto-snapshot
	next if !$IS_INCLUDED{$name};

	$name =~ m{^([^/]+)};
	my $pool = $1;

	if( $ZPOOL_STATUS{$pool} == ZPOOL_OFFLINE )
	{
		print_log(info, "Excluding $name because pool $pool is not ready.");
		next NAME;
	}

	if( $opt{'skip-scrub'} && $ZPOOL_STATUS{$pool} == ZPOOL_SCRUBBING )
	{
		print_log(info, "Excluding $name because pool $pool is scrubbing.");
		next NAME;
	}

	if( $opt{recursive} )
	{
		for(@ARGV)
		{
			if( index($name, "$_/") == 0 )
			{
				# already included by ancestor
				next NAME;
			}
		}
		for(keys %IS_INCLUDED)
		{
			next if $IS_INCLUDED{$_};
			if( index($_, "$name/") == 0 )
			{
				print_log(warning, "Excluding $name because descendant $_ is set com.sun:auto-snapshot=true.");
				next NAME;
			}
		}
		zfs_snapshot( $name );
	}
	else
	{
		zfs_snapshot( $name );
	}
}

sub help
{
	print STDERR "@_\n" if @_;
	die <<EOH;
Usage: $0 [options] [-l label] <'//' | name [name...]>
  --default-exclude  Exclude datasets if com.sun:auto-snapshot is unset.
  -d, --debug        Print debugging messages.
  -e, --event=EVENT  Set the com.sun:auto-snapshot-desc property to EVENT.
  -n, --dry-run      Print actions without actually doing anything.
  -s, --skip-scrub   Do not snapshot filesystems in scrubbing pools.
  -h, --help         Print this usage message.
  -k, --keep=NUM     Keep NUM recent snapshots and destroy older snapshots.
  -l, --label=LAB    LAB is usually 'hourly', 'daily', or 'monthly'.
  -p, --prefix=PRE   PRE is 'zfs-auto-snap' by default.
  -q, --quiet        Suppress warnings and notices at the console.
      --send-full=F  Send zfs full backup. Unimplemented.
      --send-incr=F  Send zfs incremental backup. Unimplemented.
      --sep=CHAR     Use CHAR to separate date stamps in snapshot names.
  -g, --syslog       Write messages into the system log.
  -r, --recursive    Snapshot named filesystem and all descendants.
  -v, --verbose      Print info messages.
      name           Filesystem and volume names, or '//' for all ZFS datasets.
EOH
}

sub print_log
{
	my( $level, $msg ) = @_;

	if( $opt{syslog} )
	{
		system("logger", -t => $opt{prefix}, -p => $level, $msg);
	}
	elsif( $noise >= $log_level{$level} )
	{
		warn "$msg\n";
	}
}

sub zpool_status
{
	open(my $fh, "-|", "$ZPOOL status")
		or die "$ZPOOL status: $!";
	my $pool;
	my %pools;
	while(<$fh>)
	{
		if( /^\s*pool: (.+)/ )
		{
			$pools{$pool = $1} = ZPOOL_OFFLINE;
			next;
		}
		elsif( /^\s*state: (ONLINE|DEGRADED)/ )
		{
			$pools{$pool} = ZPOOL_ONLINE;
		}
		elsif( /^\s*scan: .*scrub in progress.*/ )
		{
			$pools{$pool} = ZPOOL_SCRUBBING;
		}
	}
	return %pools;
}

sub zfs_list
{
	open(my $fh, "-|", "$ZFS list -H -t filesystem,volume -o com.sun:auto-snapshot,com.sun:auto-snapshot:$opt{label},name")
		or die "$ZFS list: $!";
	my %vols;
	my $re = $opt{'default-exclude'} ?
			qr/^true$/i :
			qr/^true|-$/i;
	VOL: while(<$fh>)
	{
		chomp;
		@_ = split /\s+/, $_, 3;
		# check com.sun:auto-snapshot
		$vols{$_[2]} = $_[0] =~ $re && $_[1] =~ $re;
	}
	return %vols;
}

sub zfs_list_snapshots
{
	open(my $fh, "-|", "$ZFS list -H -t snapshot -S creation -o name")
		or die "$ZFS list: $!";
	my @lines = <$fh>;
	chomp for @lines;
	return reverse @lines; # oldest first
}

sub zfs_snapshot
{
	my( $name ) = @_;

	my $snapname = $opt{prefix};
	$snapname .= $opt{separator}.$opt{label} if $opt{label};
	$snapname .= "-".$opt{date};

	my @props;
	push @props, "-o", "com.sun:auto-snapshot-desc='$opt{event}'" if $opt{event};

	my @flags;
	push @flags, "-r" if $opt{recursive};

	# find existing snapshots (ignoring the date and anything else trailing)
	my $snapre = $name . "@" . $opt{prefix};
	$snapre .= $opt{separator}.$opt{label} if $opt{label};
	$snapre .= "-";
	$snapre = qr/^$snapre/;

	my @old_snapshots = grep {
			$_ =~ $snapre
		} @OLD_SNAPSHOTS;

	my $ok = 1;
	while($opt{keep} && @old_snapshots > $opt{keep}-1)
	{
		my $snapshot = shift @old_snapshots;
		# sanity check for an '@', so we don't accidently destroy file systems
		die "snapshot $snapshot missing '\@'" if $snapshot !~ /@/;
		if( run($ZFS, "destroy", @flags, $snapshot) == 0)
		{
			print_log(notice, "Destroyed $snapshot");
		}
		else
		{
			print_log(error, "Error destroying $snapshot");
			$ok = 0;
			last;
		}
	}
	if( $ok && (run($ZFS, "snapshot", @props, @flags, "$name\@$snapname") == 0) )
	{
		print_log(notice, "Created $name\@$snapname");
	}
}

sub run
{
	my @cmd = @_;
	if( $opt{'dry-run'} )
	{
		print "@cmd\n";
	}
	else
	{
		system(@cmd);
	}
}
