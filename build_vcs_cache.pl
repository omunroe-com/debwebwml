#!/usr/bin/perl -w

## Quick utility - initialise a VCS cache, then save it to disk for
## others to share in the goodness

## Copyright (C) 2018  Steve McIntyre <93sam@debian.org>
##
## This program is free software; you can redistribute it and/or modify it
## under the terms of version 2 of the GNU General Public License as published
## by the Free Software Foundation.

use strict;

# These modules reside under webwml/Perl
use lib ($0 =~ m|(.*)/|, $1 or ".") ."/Perl";
use Local::VCS;
use Fcntl qw/:flock/;

my $VCS = Local::VCS->new();
my $topdir = $VCS->get_topdir();
chdir ($topdir);

my $cache_lock = ".git-revs-cache.lock";
open (my $lock, "+> $cache_lock") or die "Can't create lock file $cache_lock: $!\n";

flock ($lock, LOCK_EX);
if (!$VCS->db_cache_valid()) {
    print "Initialising VCS cache for performance\n";

    $VCS->cache_repo();
    $VCS->save_cache_to_database();
    print " ... done\n";
}
flock ($lock, LOCK_UN);

