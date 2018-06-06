#!/usr/bin/perl

## Copyright (C) 2018  Steve McIntyre <93sam@debian.org>
##
## This program is free software; you can redistribute it and/or modify it
## under the terms of version 2 of the GNU General Public License as published
## by the Free Software Foundation.

=head1 NAME

Local::VCS_git - generic wrapper around version control systems -- git version

=head1 SYNOPSIS

 use Local::VCS_git;
 use Data::Dumper;

 my $VCS = Local::VCS->new();
 my %info = $VCS->path_info( '.', recursive => 1, verbose => 1 );
 print Dumper($info{'foo.wml'});

=head1 DESCRIPTION

This module retrieves git info (such as revision of latest change, date
of latest change, author, etc) for checked-out object in a working directory.

For *best* performance if you're making lots of calls here, call
$VCS->(cache_repo) before you start. It will take a few seconds to
build a hash cache of all the git revisions for each file. If you're
only making a few calls, don't bother.

Another option (ideal for lots of separate programs all making a small
number of calls like a big "make" on the website) is to build a shared
cache on disk first. See the "build_vcs_cache.pl" script. If the
on-disk cache is initialised before the start, then all callers into
this module will benefit from a speedup almost as large as each having
a separate in-memory cache.

=head1 METHODS

=over 4

=cut

package Local::VCS_git;

use 5.008;

use File::Basename;
use File::Find;
use File::Spec::Functions qw( abs2rel rel2abs splitdir catfile rootdir catdir );
use File::stat;
use File::Path qw(make_path remove_tree);
use Carp;
use Fcntl qw/:flock/;
use POSIX qw/ WIFEXITED /;
use Cwd qw/cwd/;
use Time::HiRes qw/gettimeofday/;
use Data::Dumper;
use Digest::MD5 qw(md5 md5_hex md5_base64);

my $cache_db = ".git-revs-cache.db";
my $cache_lock = ".git-revs-cache.lock";
my $git_index = ".git/index";

use strict;
use warnings;

BEGIN {
	use base qw( Exporter );

	our $VERSION = "1.13";
	our @EXPORT_OK = qw( 
			     &new
	                   );
	our %EXPORT_TAGS = ( 'all' => [@EXPORT_OK] );
}

=item new

This is the constructor.

   my $VCS = Local::VCS->new();

=cut

sub new {
        my $class = shift;
	my %params = @_;
        my $self  = {
	    CACHE    => {},
	    # Possible REPO_CACHED values:
	    # 0 == not all cached          (slowest)
	    # 1 == cached in a valid db (disk files)
	    # 2 == cached in a hash in RAM (fastest)
	    REPO_CACHED => 0,
	    DEBUG => 0,
        };
        bless ($self, $class);

	if ($params{"DEBUG"}) {
	    $self->{DEBUG} = $params{"DEBUG"};
	}

	if ($self->db_cache_valid()) {
	    $self->{REPO_CACHED} = 1;
	}
        return $self;
}

sub _get_time()
{
    my @tm;
    my $text;
    my ($seconds, $microseconds) = gettimeofday;

    @tm = gmtime();
    $text = sprintf("%4d-%02d-%02d %02d:%02d:%02d.%06d UTC",
                    (1900 + $tm[5]),(1 + $tm[4]),$tm[3],$tm[2],$tm[1],$tm[0], $microseconds);
    return $text;
}

sub _debug
{
    my $self = shift;
    my @text = @_;
    return unless $self->{DEBUG};
    my $timestamp = _get_time();
    print STDERR "=> ", $timestamp, " ", @text, "\n";
    return;
}

# Internal helper function. Try to change to the target directory. If
# we can't for some reason (e.g. it doesn't exist), print an error
# *and* change to the fallback directory instead, then return false..
#
# Useful in a number of places in this code where we're in a nested
# set of chdir() calls and we want to exit cleanly on error
sub _safe_chdir {
    my $target = shift;
    my $fallback = shift;

    if (!chdir($target)) {
	print STDERR "ERROR: Can't chdir to $target: $!\n";
	chdir($fallback) or die "Can't chdir to fallback dir $fallback: $!\n";
	return 0;
    }
    return 1;
}

sub _add_cache_entry {
    my $self = shift;
    my $file = shift;
    my %entry;
    $entry{'cmt_date'} = shift;
    $entry{'cmt_rev'} = shift;
    my $tmp;
    my @list;
#    print __LINE__ . ": adding $file, " . Dumper(%cache);
    if ($self->{CACHE}{"$file"}) {
	$tmp = $self->{CACHE}{"$file"};
	@list = @$tmp;
    }
    push(@list, \%entry);
    $self->{CACHE}{"$file"} = \@list;
}

sub cache_file {
    my $self = shift;
    my $file = shift;
    
    $self->_debug( "cache_file($file)");

    if ($self->{REPO_CACHED}) {
	$self->_debug( "cache_file() returning early - whole repo already cached");
	return;
    }

    if ($self->{CACHE}{"$file"}) {
	$self->_debug( "$file is already cached...");
	$self->_debug( "cache_file($file) returning early");
	return;
    }
    $self->_debug( "Adding $file to cache\n");

    # Store the current directory so we can return there
    my $startdir = cwd;
    my $topdir = $self->get_topdir();
    _safe_chdir($topdir, $startdir) or die "Can't chdir to $topdir: $!\n";

    my (@commits);
    open (GITLOG, "git log -p -m --first-parent --name-only --numstat --format=format:\"%H %ct\" -- $file |") or die "Can't fork git log: $!\n";
    my ($cmt_date, $cmt_rev);
    while (my $line = <GITLOG>) {
	chomp $line;
	if ($line =~ m/^([[:xdigit:]]+) (\d+)$/) {
	    $cmt_rev = $1;
	    $cmt_date = $2;
	    next;
	} elsif ($line =~ m{^$file$}) {
	    $self->_add_cache_entry($file, $cmt_date, $cmt_rev);
	}
    }
    close GITLOG;
    $self->_debug( "cache_file($file) done");
    chdir ($startdir);
    return;
}

sub db_cache_valid {
    my $self = shift;
    my $valid = 0;

    # If we can't find the right dir, it can't be valid!
    my $topdir = $self->get_topdir() or return 0;

    $self->_debug( "db_cache_valid");

    # Check to see if an existing cache DB file is up to date
    # compared to the git index.
    if (-d "$topdir/$cache_db") {

	$self->_debug( "db_cache_valid: file $topdir/$cache_db exists ok");

	my $dbs = stat("$topdir/$cache_db");
	my $ids = stat("$topdir/$git_index");

	my $mtime1 = $dbs->mtime;
	my $mtime2 = $ids->mtime;
	$self->_debug( "dbs has mtime $mtime1, ids has mtime $mtime2");

	if ($dbs->mtime < $ids->mtime) {
	    $self->_debug( "db_cache_valid: but is out of date, rebuild needed");
	    $valid = 0;
	} else {
	    $valid = 1;
	}
    } else {
	# We don't have a cache file, we have to rebuild it
	$valid = 0;
	$self->_debug( "db_cache_valid: dir does not exist, so not valid");
    }
    return $valid;
}

# Internal helper string - (md5) hash a string and return the hash
sub _hash_string {
    my $string = shift;
    return md5_hex($string);
}

# Dump our hashed cache out to disk so we can share it with other
# processes
sub save_cache_to_database {
    my $self = shift;
    my %args = @_;
    my $tmp_cache_db = "$cache_db.tmp";
    my $query;

    print Dumper(%args);

    $self->_debug( "save_cache_to_database starting");

    # Now we're locked, see if the db s valid - somebody else might
    # have updated it for us!
    if (! $args{"FORCE"} and $self->db_cache_valid()) {
	$self->_debug( "save_cache_to_database: Not rebuilding cache, it's already valid now");
	return;
    }

    remove_tree($cache_db);
    make_path($tmp_cache_db);

    my $tmp = $self->{CACHE};
    my $table_count = 0;
    my $row_count = 0;

    foreach my $key(sort keys %$tmp) {
	my $file = $key;
	my $tmp1 = $self->{CACHE}{"$file"};
	my @list = @$tmp1;
	my $tablename = _hash_string($file);

	open (OUT, "> $tmp_cache_db/$tablename") or die "Can't create file $tmp_cache_db/$tablename: $!\n";
	$table_count++;
	foreach my $tmp2 (@list) {
	    my %entry = %$tmp2;
	    printf OUT "%s %s\n", $entry{"cmt_date"}, $entry{"cmt_rev"};
	    $row_count++;
	}
	if (0 == $table_count % 1000 or $table_count == scalar(keys %$tmp)) {
	    $self->_debug( "$row_count rows, $table_count tables done");
	}
	close OUT;
    }

    rename $tmp_cache_db, $cache_db;
    $self->_debug( "save_cache_to_database done");
}

sub cache_repo {
    my $self = shift;

    $self->_debug( "cache_repo()");
    # If we've already read the commit history into our cache, return
    # immediately
    if ($self->{REPO_CACHED} == 2) {
	$self->_debug( "cache_repo() returning early");
	return;
    }

    # Store the current directory so we can return there
    my $startdir = cwd;
    my $topdir = $self->get_topdir();
    _safe_chdir($topdir, $startdir) or die "Can't chdir to $topdir: $!\n";

    # Clear the cache and rebuild from scratch. We might havs
    # some files cached individually, and that would confuse
    # things now.
    $self->{CACHE} = {};
#	    print __LINE__ . ": " . Dumper(%cache);

    my (@commits);
    my $count = 0;
    open (GITLOG, "git log -p -m --first-parent --name-only --numstat --format=format:\"%H %ct\" |") or die "Can't fork git log: $!\n";
    my ($cmt_date, $cmt_rev);
    while (my $line = <GITLOG>) {
	chomp $line;
	if ($line =~ m/^([[:xdigit:]]+) (\d+)$/) {
	    $cmt_rev = $1;
	    $cmt_date = $2;
	    next;
	} elsif ($line =~ m{^(\S+)$}) {
	    my $file = $1;
	    $self->_add_cache_entry($file, $cmt_date, $cmt_rev);
	    $count++;
	}
    }
    close GITLOG;
    $self->{REPO_CACHED} = 2;
    my $tmp = $self->{CACHE};
    my $num_files = scalar(keys %$tmp);
    $self->_debug( "cache_repo() done, $count file commits, $num_files files");

    chdir ($startdir);
}    

# Internal helper function - grab a list of all the commits to a given
# file. This mist be relative to the top level of the repository. The
# caller must deal with this
sub _grab_commits
{    
    my $self = shift;
    my $file = shift or return undef;
    $self->cache_file($file);

    if ($self->{REPO_CACHED} == 1) {
	# Grab from the on-disk files
	my $tablename = _hash_string($file);
	my $commits;
	# Take a shared lock to stop somebody taking the cache out
	# from underneath us
	open (my $lock, "+> $cache_lock") or die "Can't create lock file $cache_lock: $!\n";
	flock ($lock, LOCK_SH);
	open (IN, "< $cache_db/$tablename") or die "Can't open file $cache_db/$tablename: $!\n";
	my @commits;
	while(my $line = <IN>) {
	    if ($line =~ m/^(\d+)\s+([[:alnum:]]+)$/) {
		my %entry = (
		    'cmt_date' => $1,
		    'cmt_rev'  => $2,
		    );
		push (@commits, \%entry);
	    } else {
		print STDERR "ERROR: Can't parse $line in $cache_db/$tablename for file $file\n";
	    }
	}
	close IN;
	flock ($lock, LOCK_UN);
	close ($lock);
	#	print Dumper(@commits);
	return @commits;
    } else {
	# Return directly from the in-memory cache
	my $tmp = $self->{CACHE}{"$file"};
	if (defined $tmp) {
	    my @commits = @$tmp;
	    #    print Dumper(@commits);
	    return @commits;
	}
	return undef;
    }
}

=item cmp_rev

Compare two revision strings for a given file.

Takes the file path and two revision strings as arguments, and 
returns 1 if the first one is newer, 
-1 if the second one is newer, 
0 if they are equal

=cut
sub cmp_rev
{
	# For the file we're looking at, we can easily generate an
	# array (list) of all the commit hashes. Then we can see where
	# in that list the specified revisions lie (from newest to
	# oldest) - that's what we're going to compare.

	my $self = shift;
	my $file = shift or return undef;
	my $rev1 = shift or return undef;
	my $rev2 = shift or return undef;
	my $ret = undef;

	# Work out where we need to be. This can be quite hairy if the
	# user has given us a mix of relative and absolute paths from
	# their program. Do this cleanly, somehow...!
	# First of all, store the current directory so we can return
	# there
	my $startdir = cwd;
	my $indir = dirname($file);
	my $basefile = basename($file);
	# Change to the directory of the file we've been asked about
	_safe_chdir($indir, $startdir) or return undef;
	$indir = cwd;
	# That should be inside the repo, so now we can change to the
	# repo root
	my $topdir = $self->get_topdir();
	_safe_chdir($topdir, $startdir) or return undef;
	# Now calculate where the file is, relative to the repo root
	my $reldir = abs2rel($indir, cwd);
	my $relfile = catdir($reldir, $basefile);
	$self->_debug( "cmp_rev(): looking for details of file $relfile, indir $indir");

	my @commits = $self->_grab_commits($relfile);
#	print Dumper(@commits);
	my $pos1 = -1;
	my $pos2 = -1;
	my $count = 0;
	foreach my $tmp(@commits) {
	    my %entry = %$tmp;
	    if ($entry{'cmt_rev'} =~ /\Q$rev1\E/) {
		$pos1 = $count;
	    }
	    if ($entry{'cmt_rev'} =~ /\Q$rev2\E/) {
		$pos2 = $count;
	    }
	    if ($pos1 != -1 and $pos2 != -1) {
		last;
	    }
	    $count++;
	}
	if ($pos1 == -1) {
	    # Not found
	    print STDERR "ERROR: commit $rev1 not found in revisions of $file\n";
	    $ret = undef;
	} elsif ($pos2 == -1) {
	    # Not found
	    print STDERR "ERROR: commit $rev2 not found in revisions of $file\n";
	    $ret = undef;
	} elsif ($pos1 == $pos2) {
	    $ret = 0;
	} elsif ($pos1 < $pos2) {
	    $ret = 1;
	} else {
	    $ret = -1;
	}

	# Now return to the directory where we started
	chdir($startdir);
	return $ret;
}

=item count_changes

Return the number of changes to particular file between two revisions

The first argument is a name of a file.
The second and third argument specify the revision range

Example use:

   my $num1 = count_changes( 'foo.c', 'r42', 'r70' );
   my $num2 = count_changes( 'foo.c', 'r42', 'HEAD' );
   
=cut

sub count_changes
{
	# FIXME: not sure if we need to handle the issue of wrong $rev1/$rev2 here
	#        or the caller function will care.
	#        Not sure if this function makes sense in a git context, either,
	#        but just in case
    
	my $self = shift;
	my $file = shift  or  return undef;
	my $rev1 = shift || '';
	my $rev2 = shift || '';
	my $ret = 0;

	if ($rev1 =~ m/^\Q$rev2\E$/) { # same revisions
	    return 0;
	}

	# Work out where we need to be. This can be quite hairy if the
	# user has given us a mix of relative and absolute paths from
	# their program. Do this cleanly, somehow...!
	# First of all, store the current directory so we can return
	# there
	my $startdir = cwd;
	my $indir = dirname($file);
	my $basefile = basename($file);
	# Change to the directory of the file we've been asked about
	_safe_chdir($indir, $startdir) or return undef;
	$indir = cwd;
	# That should be inside the repo, so now we can change to the
	# repo root
	my $topdir = $self->get_topdir();
	_safe_chdir($topdir, $startdir) or return undef;
	# Now calculate where the file is, relative to the repo root
	my $reldir = abs2rel($indir, cwd);
	my $relfile = catdir($reldir, $basefile);
	$self->_debug( "count_changes(): looking for details of file $relfile, indir $indir");

	my @commits = $self->_grab_commits($relfile);

	# If unset, go for the last revision
	if (length($rev2) == 0) {
	    $rev2 = $commits[$#commits];
	}

	my $pos1 = -1;
	my $pos2 = -1;
	my $count = 0;
	foreach my $tmp(@commits) {
	    my %entry = %$tmp;
	    if ($entry{'cmt_rev'} =~ /\Q$rev1\E/) {
		$pos1 = $count;
	    }
	    if ($entry{'cmt_rev'} =~ /\Q$rev2\E/) {
		$pos2 = $count;
	    }
	    if ($pos1 != -1 and $pos2 != -1) {
		last;
	    }
	    $count++;
	}
	if ($pos1 == -1) {
	    # Not found
	    print STDERR "count_changes() ERROR: commit rev1 $rev1 not found in revisions of $file\n";
	    $ret = undef;
	} elsif ($pos2 == -1) {
	    # Not found
	    print STDERR "count_changes() ERROR: commit rev2 $rev2 not found in revisions of $file\n";
	    $ret = undef;
	} else {
	    $ret = $pos1 - $pos2;
	}
	# Now return to the directory where we started
	chdir($startdir);
	return $ret;
}

# return the type of the input argument (file, dir, symlink, etc)
sub _typeoffile
{
	my $file = shift  or  return;

	stat $file  or  return 'f'; # File is not here now; assume it
				    # was a file!

	return 'f'  if ( -f _ );
	return 'd'  if ( -d _ );
	return 'l'  if ( -l _ );
	return 'S'  if ( -S _ );
	return 'p'  if ( -p _ );
	return 'b'  if ( -b _ );
	return 'c'  if ( -c _ );

	return '';
}

=item path_info

Return git information and status about a tree of files.

The first argument is a name of a file or directory, and subsequent arguments
form a hash of named options (see below).

The function returns a hash, which for each filename contains
git status information:

  'type'       => type of the file ('d' directory, 'f' regular file, etc)
  'cmt_rev'    => revision in which latest change was made to this file
  'cmt_date'   => date on which latest change to this file was committed

Optional remaining arguments are a hash array with options:

   recursive:  if set to a true value (and the specified file is a directory),
               recurse into subdirectories
   match_pat:  only files/dirs that match this pattern are processed
   skip_pat:   files/dirs that match this pattern are skipped

Example uses:

   my %info1 = $VCS->path_info( 'src' );
   my %info2 = $VCS->path_info( 'src', recursive => 1 );
   my %info3 = $VCS->path_info( 'src', recursive => 1, match_pat => '\.c$' );

=cut

# todo: verbose

sub path_info
{
	# Two parts:
	#
	# (1)  Build a hash of all the files we want to know about
	#
	# (2a) Ask git about all the files it has, and pull out
	#      information for ones in the hash from (1)
	#
	# OR
	# 
	# (2b) Grab that information from our cache of all the commit data,
	#      if we have already been told to generate that cache.
	#      *Don't* generate that cache automatically - for just a few
	#      files it's quicker to just look up the data directly. If the
	#      user is going to do a lot of lookups, let them populate the
	#      cache up-front themselves if performance matters.
	#
	# This may not sound very quick, but it's much better than asking git
	# about all the details individually!

	# FIXME! path_info will not work unless you start at the root
	# of the repository.

	my $self = shift;
	my ($dir,%options) = @_;
	my %files_wanted;

	croak("No file or directory specified") unless $dir;
	$self->_debug( "path_info ($dir)");
	if ($self->get_topdir() !~ /^\.$/) {
	    croak "path_info() needs to be called in the root of the webwml repo\n";
	}

	my $recurse   = $options{recursive} || $options{recurse} || 0;
	my $match_pat = $options{match_pat} || undef;
	my $skip_pat  = $options{skip_pat}  || undef;

	$self->_debug( "Recurse is $recurse");
	$self->_debug( "Match pattern is '$match_pat'") if defined $match_pat;
	$self->_debug( "Skip pattern is  '$skip_pat'")  if defined $skip_pat;

	if ($recurse) {
	    find( sub { $files_wanted{$File::Find::name} = 1 if -f and
			    (!defined $match_pat or m/$match_pat/) and
			    (!defined $skip_pat or not ($File::Find::name =~ m/$skip_pat/))}, $dir );
	} else {
	    find( sub { $files_wanted{$File::Find::name} = 1 if -f and
			    ($File::Find::dir eq $dir) and
			    (!defined $match_pat or m/$match_pat/) and
			    (!defined $skip_pat or not ($File::Find::name =~ m/$skip_pat/))}, $dir );
	}

	# Calling "git log" for each file individually is hatefully
	# slow. Better option: call it once with appropriate options
	# for the directory we're targeting, and parse the
	# output. Gross, but it works.

	my %pathinfo;

	# Do we have the repo commit history cached?
	if ($self->{REPO_CACHED}) {
		# We do, use it! (2b above)
		foreach my $file (keys %files_wanted) {
		    my @commits = $self->_grab_commits($file);
		    if (@commits) {
			my $outfile = $file;
			$outfile =~ s,^$dir/,,;
			# Grab the data we want from the first entry in the
			# commits list, i.e. the most recent commit.
			$pathinfo{$outfile}{'type'} = _typeoffile("$file");
			$pathinfo{$outfile}{'cmt_date'} = $commits[0]{'cmt_date'};
			$pathinfo{$outfile}{'cmt_rev'} = $commits[0]{'cmt_rev'};
		    } else {
			$self->_debug( "Ignoring file $file");
		    }
		}
	} else {
	    # We don't, so we need to talk to git. (2a above)
	    open (GITLOG, "git log -p -m --first-parent --name-only --numstat --format=format:\"%H %ct\" $dir|")
		or die "Failed to fork git log: $!\n";
	    my $cmt_date;
	    my $cmt_rev;
	    my $file;
	    while (my $line = <GITLOG>) {
		chomp $line;
		if ($line =~ m/^([[:xdigit:]]+) (\d+)$/) {
		    $cmt_rev = $1;
		    $cmt_date = $2;
		    next;
		} elsif ($line =~ m{^$dir/(\S+)$}) {
		    $file = $1;
		    # Only store information if:
		    # We want this file, and
		    # We don't have data for it yet (i.e. only show
		    # the most recent version of a file)
		    if ($files_wanted{"$dir/$file"} and not defined $pathinfo{$file}) {
			$pathinfo{$file}{'type'} = _typeoffile("$dir/$file");
			$pathinfo{$file}{'cmt_date'} = $cmt_date;
			$pathinfo{$file}{'cmt_rev'} = $cmt_rev;
		    }
		}   
	    }
	    close GITLOG;
	}
	$self->_debug( "path_info ($dir) returning");
	return %pathinfo;	
}

=item file_info

Return VCS information and status about a single file

The single argument is a name of a file.

The function returns a hash, which contains VCS status information for
the specified file:

  'type'       => type of the file ('d' directory, 'f' regular file, etc)
  'cmt_rev'    => revision in which latest change was made to this file
  'cmt_date'   => date on which latest change to this file was committed

Example use:

   my %info = $VCS->file_info( 'foo.wml' );

=cut

sub file_info
{
	my $self = shift;
	my $file = shift or carp("No file specified");
	my %options = @_;
	my $quiet = $options{quiet} || undef;
	my %pathinfo;

	# Work out where we need to be. This can be quite hairy if the
	# user has given us a mix of relative and absolute paths from
	# their program. Do this cleanly, somehow...!
	# First of all, store the current directory so we can return
	# there
	my $startdir = cwd;
	my $indir = dirname($file);
	my $basefile = basename($file);
	# Change to the directory of the file we've been asked about
	_safe_chdir($indir, $startdir) or return undef;
	$indir = cwd;
	# That should be inside the repo, so now we can change to the
	# repo root
	my $topdir = $self->get_topdir();
	_safe_chdir($topdir, $startdir) or return undef;
	# Now calculate where the file is, relative to the repo root
	my $reldir = abs2rel($indir, cwd);
	my $relfile = catdir($reldir, $basefile);
	$self->_debug( "file_info(): looking for details of file $relfile, indir $indir");
	my @commits = $self->_grab_commits($relfile);
	if (@commits) {
	    # Grab the data we want from the first entry in the
	    # commits list, i.e. the most recent commit.
	    $pathinfo{'type'} = _typeoffile("$file");
	    $pathinfo{'cmt_date'} = $commits[0]{'cmt_date'};
	    $pathinfo{'cmt_rev'} = $commits[0]{'cmt_rev'};
	}

	# Now return to the directory where we started
	chdir($startdir);
	return %pathinfo;	
}

=item get_log

Return the log info about a specified file

The first argument is a name of a checked-out file.
The (optional) second and third argument specify the starting and end revision
of the log entries

Example use:

   my @log_entries = get_log( 'foo.wml' );
   
=cut

sub get_log
{
	my $self = shift;
	my $file = shift  or  return;
	my $rev1 = shift || '';
	my $rev2 = shift || '';
	my @logdata;
	my $command;	

	# Work out where we need to be. This can be quite hairy if the
	# user has given us a mix of relative and absolute paths from
	# their program. Do this cleanly, somehow...!
	# First of all, store the current directory so we can return
	# there
	my $startdir = cwd;
	my $indir = dirname($file);
	my $basefile = basename($file);
	# Change to the directory of the file we've been asked about
	_safe_chdir($indir, $startdir) or return undef;
	$indir = cwd;
	# That should be inside the repo, so now we can change to the
	# repo root
	my $topdir = $self->get_topdir();
	_safe_chdir($topdir, $startdir) or return undef;
	# Now calculate where the file is, relative to the repo root
	my $reldir = abs2rel($indir, cwd);
	my $relfile = catdir($reldir, $basefile);
	$self->_debug( "get_log(): looking for details of file $relfile, indir $indir");

	if ($rev1 eq '' and $rev2 eq '') {
	    $command = sprintf( 'git log --date=unix %s', $relfile );
	} elsif ($rev2 eq '') {
	    $command = sprintf( 'git log --date=unix %s^..%s %s', $rev1, $rev1, $relfile );
	} elsif ($rev1 eq '') {
	    $command = sprintf( 'git log --date=unix ..%s %s', $rev2, $relfile );
	} else {
	    $command = sprintf( 'git log --date=unix %s..%s %s', $rev1, $rev2, $relfile );
	}		

	$self->_debug( "get_log: running $command");

	open( my $git, '-|', $command ) 
		or croak("Couldn't run `$command': $!");

	my $revision;
	my $author;
	my $date;
	my $message;
	my $first_record_done = 0;

	# read and parse the log records
	while ( my $line = <$git> )
	{
	    # the first 3 lines of a record contain metadata that looks like this:
	    # commit abcdefg435768938de
	    # Author: Jane Doe <email@example.com>
	    # Date:   1504881409

	    if ($line =~ m{^commit (.+)}) {
		# Second and subsequent record, push a result
		if ($first_record_done) {
		    $self->_debug( "pushing a record (rev $revision)");
		    push @logdata, {
			'rev'     => $revision,
		        'author'  => $author,
			'date'    => $date,
			'message' => $message,
		    };
		    $message = "";
		}
		$first_record_done = 1;
		$revision = $1;
	    } elsif ($line =~ m{^Author: (.+)}) {
		$author = $1;
	    } elsif ($line =~ m{^Date: (.+)}) {
		$date = $1;
	    } else {
		# Lose leading whitespace, but retain blank lines
		if ($line =~ m{\S}) {
		    $line =~ s{^\s+}{};
		}
		$message .= $line;
	    }

	}
	close( $git );

	if ($first_record_done) {
	    #	$self->_debug( "pushing last record (rev $revision)");
	    # Last record, push a result
	    push @logdata, {
		'rev'     => $revision,
		 'author'  => $author,
		 'date'    => $date,
		 'message' => $message,
	    };
	    chdir($startdir);
	    return reverse @logdata;
	}
	chdir($startdir);
	return undef;
}

=item get_diff

Returns a hash of (filename,diff) pairs containing the unified diff between two version of a (number of) files.

The first argument is a name of a checked-out file.  The second and third
argument specify the starting and end revision of the log entries.  If the
third argument is not specified, the current (possibly modified) version is
used.  If the second argument is also not specified, the current (possibly
modified) version is diffed against the latest checked in version.

Example use:

   my %diffs = get_diff( 'foo.wml', '1.4', '1.17' );
   my %diffs = get_diff( 'bla.wml', '1.8' );
   my %diffs = get_diff( 'bas.wml' );
   

=cut

sub get_diff
{
	my $self = shift;
	my $file = shift  or  return;
	my $rev1 = shift;
	my $rev2 = shift;

	# hash to store the output
	my %data;

	# Work out where we need to be. This can be quite hairy if the
	# user has given us a mix of relative and absolute paths from
	# their program. Do this cleanly, somehow...!
	# First of all, store the current directory so we can return
	# there
	my $startdir = cwd;
	my $indir = dirname($file);
	my $basefile = basename($file);
	# Change to the directory of the file we've been asked about
	_safe_chdir($indir, $startdir) or return undef;
	$indir = cwd;
	# That should be inside the repo, so now we can change to the
	# repo root
	my $topdir = $self->get_topdir();
	_safe_chdir($topdir, $startdir) or return undef;
	# Now calculate where the file is, relative to the repo root
	my $reldir = abs2rel($indir, cwd);
	my $relfile = catdir($reldir, $basefile);
	$self->_debug( "get_diff(): looking for details of file $relfile, indir $indir");

	my $command = sprintf( 'git diff %s %s -u %s 2> /dev/null', 
		defined $rev1 ? "$rev1" : '', 
		defined $rev2 ? "$rev2" : '', 
		$relfile );

#	print "$command\n";

	open( my $git, '-|', $command ) 
		or croak("Couldn't run `$command': $!");

	# read the consecutive records
	while ( my $record = <$git> )
	{
		# remove the record separator from the end of the record
#		$record =~ s{ $/ \n? \Z }{}msx;

		# remove the "index" line from the beginning of the record
#		$record =~ s{ ^index [^\n] }{}msx;

		# remove the first 2 lines
		$record =~ s{^diff\s+--git.*}{}msx;
		$record =~ s{^index\s+.*}{}msx;

		$data{$file} .= $record;
	}
	close( $git );

	# Now return to the directory where we started
	chdir($startdir);
	return %data;
}


=item get_file

Return a particular revision of a file

The first argument is a name of a file.
The second argument is the revision.

This function retrieves the specified revision fo the file from the repository
and returns it (without writing anything in the current checked-out tree)

Example use:

   my $text = get_file( 'foo.c', '1.12' );

=cut

sub get_file
{
	my $self = shift;
	my $file = shift or croak("No file specified");
	my $rev  = shift or croak("No revision specified");

	croak( "No such file: $file" ) unless -f $file;

	# Work out where we need to be. This can be quite hairy if the
	# user has given us a mix of relative and absolute paths from
	# their program. Do this cleanly, somehow...!
	# First of all, store the current directory so we can return
	# there
	my $startdir = cwd;
	my $indir = dirname($file);
	my $basefile = basename($file);
	# Change to the directory of the file we've been asked about
	_safe_chdir($indir, $startdir) or return undef;
	$indir = cwd;
	# That should be inside the repo, so now we can change to the
	# repo root
	my $topdir = $self->get_topdir();
	_safe_chdir($topdir, $startdir) or return undef;
	# Now calculate where the file is, relative to the repo root
	my $reldir = abs2rel($indir, cwd);
	my $relfile = catdir($reldir, $basefile);
	$self->_debug( "get_file(): looking for details of file $relfile, indir $indir");

	my $command = sprintf( 'git show %s:%s', 
		$rev, $relfile );

	my $text;
	open ( my $git, '-|', $command ) 
		or croak("Error while executing `$command': $!");
	while ( my $line = <$git> )
	{
		$text .= $line;
	}
	close( $git );
	croak("Error while executing `$command': $!") unless WIFEXITED($?);
	
	# Now return to the directory where we started
	chdir($startdir);

	# return the file
	return $text;
}

=item get_oldest_revision

Return the version of the oldest version of a file

The first argument is a name of a file.

This function finds the oldest revision of a file that is known in the repository and returns it.

Example use:

   my $rev = get_oldest_revision( 'foo.c');

=cut

sub get_oldest_revision
{
	my $self = shift;
	my $file = shift or croak("No file specified");
	my $ret = undef;

	croak( "No such file: $file" ) unless -f $file;

	# Work out where we need to be. This can be quite hairy if the
	# user has given us a mix of relative and absolute paths from
	# their program. Do this cleanly, somehow...!
	# First of all, store the current directory so we can return
	# there
	my $startdir = cwd;
	my $indir = dirname($file);
	my $basefile = basename($file);
	# Change to the directory of the file we've been asked about
	_safe_chdir($indir, $startdir) or return undef;
	$indir = cwd;
	# That should be inside the repo, so now we can change to the
	# repo root
	my $topdir = $self->get_topdir();
	_safe_chdir($topdir, $startdir) or return undef;
	# Now calculate where the file is, relative to the repo root
	my $reldir = abs2rel($indir, cwd);
	my $relfile = catdir($reldir, $basefile);
	$self->_debug( "get_oldest_revision(): looking for details of file $relfile, indir $indir");

	my @commits = $self->_grab_commits($relfile);

	if (@commits) {
	    # Simply return the last revision in our list
	    $ret = $commits[$#commits]{'cmt_rev'};
	} else {
	    # Should hopefully never get here!
	    croak(" Could not find any revisions for $file");
	}

	# Now return to the directory where we started
	chdir($startdir);

	# return the information
	return $ret;
}

=item get_newest_revision

Return the version of the newest version of a file

The first argument is a name of a file.

This function finds the newest revision of a file that is known in the
repository and returns it.

Example use:

   my $rev = get_newest_revision( 'foo.c');

=cut

sub get_newest_revision
{
	my $self = shift;
	my $file = shift or croak("No file specified");
	my $ret = undef;

	croak( "No such file: $file" ) unless -f $file;

	# Work out where we need to be. This can be quite hairy if the
	# user has given us a mix of relative and absolute paths from
	# their program. Do this cleanly, somehow...!
	# First of all, store the current directory so we can return
	# there
	my $startdir = cwd;
	my $indir = dirname($file);
	my $basefile = basename($file);
	# Change to the directory of the file we've been asked about
	_safe_chdir($indir, $startdir) or return undef;
	$indir = cwd;
	# That should be inside the repo, so now we can change to the
	# repo root
	my $topdir = $self->get_topdir();
	_safe_chdir($topdir, $startdir) or return undef;
	# Now calculate where the file is, relative to the repo root
	my $reldir = abs2rel($indir, cwd);
	my $relfile = catdir($reldir, $basefile);
	$self->_debug( "get_newest_revision(): looking for details of file $relfile, indir $indir");

	my @commits = $self->_grab_commits($relfile);
	if (@commits) {
	    # Simply return the first revision in our list
	    $ret = $commits[0]{'cmt_rev'};
	} else {
	    # Should hopefully never get here!
	    croak(" Could not find any revisions for $file");
	}

	# Now return to the directory where we started
	chdir($startdir);

	# return the information
	return $ret;
}

=item next_revision

Given a file path and a current revision of that file, move backwards
or forwards through the commit history and return a related revision.

Takes three arguments: the file path, the start revision and an
integer to specify which direction to move *and* how far. A negative
number specifies backwards in history, a positive number specifies
forwards.

Example use:

   my $rev = next_revision( 'foo.c', '72f6700577c79e6d284fbeac44366f6aa357d56d', -1);

Returns the requested revision if it exists, otherwise *undef*

=cut
sub next_revision
{
	# For the file we're looking at, we can easily generate an
	# array (list) of all the commit hashes. Then we can see where
	# in that list the specified revision lies.

	my $self = shift;
	my $file = shift or return undef;
	my $rev1 = shift or return undef;
	my $move = shift or return undef;
	my $ret = undef;

	croak( "No such file: $file" ) unless -f $file;

	# Work out where we need to be. This can be quite hairy if the
	# user has given us a mix of relative and absolute paths from
	# their program. Do this cleanly, somehow...!
	# First of all, store the current directory so we can return
	# there
	my $startdir = cwd;
	my $indir = dirname($file);
	my $basefile = basename($file);
	# Change to the directory of the file we've been asked about
	_safe_chdir($indir, $startdir) or return undef;
	$indir = cwd;
	# That should be inside the repo, so now we can change to the
	# repo root
	my $topdir = $self->get_topdir();
	_safe_chdir($topdir, $startdir) or return undef;
	# Now calculate where the file is, relative to the repo root
	my $reldir = abs2rel($indir, cwd);
	my $relfile = catdir($reldir, $basefile);
	$self->_debug( "next_revision(): looking for details of file $relfile, indir $indir");

	my @commits = $self->_grab_commits($relfile);
#	print Dumper(@commits);
	my $pos1 = -1;
	my $pos2 = -1;
	my $count = 0;
	my %entry;
	foreach my $tmp(@commits) {
	    %entry = %$tmp;
	    if ($entry{'cmt_rev'} =~ /\Q$rev1\E/) {
		$pos1 = $count;
	    }
	    if ($pos1 != -1) {
		last;
	    }
	    $count++;
	}

	if ($pos1 == -1) {
	    # Can't find the specified revision
	    $ret = undef;
	} else {
	    # API specifies -ve as older, but out list is sorted the other
	    # way...
	    $pos2 = $pos1 - $move;

	    if ($pos2 < 0 or $pos2 >= $#commits) {
		# Out of range when looking for the new revision
		$ret = undef;
	    } else {
		$ret = $commits[$pos2]{'cmt_rev'};
	    }
	}

	# Now return to the directory where we started
	chdir($startdir);

	# return the information
	return $ret;
}

=item get_topdir

Return the top dir of the webwml repository

The first argument is a name of a checked-out file or directory.
If it is not specified, by default the current directory is used.

Example use:

   my $dir = get_topdir( 'foo.c' );

=cut

sub get_topdir
{
	my $self = shift;
	my $file = shift || '.';

	# Are we in topdir? Easy!
	if (-d ".git" and -d "english") {
	    return ".";
	}

	# Otherwise, walk up the tree until we find a .git or hit the
	# root directory
	my $dir = "..";
	my $root = stat("/");

	while (1 == 1) {
	    $self->_debug( "Looking at $dir");
	    if (-d "$dir/.git" and -d "$dir/english") {
		return "$dir";
	    }
	    my $sb = stat("$dir");
	    $self->_debug( "Comparing ($sb->dev, $sb->ino) to ($root->dev, $root->ino)");
	    if ($root->dev == $sb->dev and $root->ino == $sb->ino) {
		croak ("Unable to find the top-level webwml directory");
	    }
	    $dir = "../$dir";
	}
}

=back

=head1 AUTHOR

Copyright (C) 2018  Steve McIntyre <93sam@debian.org>

This program is free software; you can redistribute it and/or modify
it under the terms of version 2 of the GNU General Public License as
published by the Free Software Foundation.

=cut

42;


__END__


