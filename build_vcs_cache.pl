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

my $VCS = Local::VCS->new();
print "Initialising VCS cache for performance\n";
$VCS->cache_repo();
$VCS->save_cache_to_database();
print " ... done\n";

