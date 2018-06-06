#!/usr/bin/perl -w

# This script is used during build of English documents to check if
# translations are up-to date.

# This script takes full path to a original .wml file, and the language of
# the original.
# For every language defined in @langs, the script:
#	- checks if a translated file exists for such language
#	- checks if the translated file is at least N revisions old
#	  (N is any number defined in @stages)
#	- if it is, and it hasn't been touched because of this particular
#	  "N", it is touched and a marker file is created
# This allows the file to be rebuilt _exactly_ the number of times it should
# (i.e. $#stages times)
#
# (C) 2000 by Marcin Owsiany <porridge@pandora.info.bielsko.pl>
#     Original script
#
# (C) 2018 Steve McIntyre <93sam@debian.org>
#     Converted to use Local::VCS to allow for usage with git instead of CVS
#
#    These modules reside under webwml/Perl

use lib ($0 =~ m|(.*)/|, $1 or ".") ."/Perl";
use Local::VCS;
use Webwml::Langs;
use Webwml::TransCheck;

# Set this to non-zero for debugging
$debug = 0;

my $VCS = Local::VCS->new("DEBUG" => $debug);

sub rebuild {
    my $file = shift;
    $now = time;
    print "touching $file\n" if $debug;
    utime $now, $now, $file or die "$file: $!";
}

sub mark_forced {
    my $file = shift;
    my $val = shift;
    my $foo = "$file".".forced";
    open LOG, ">$foo" or die "$foo: $!";
    print LOG "$val";
    close LOG;
    print "Created $file.forced with $val inside\n" if $debug;
}

sub was_forced {
    my $file = shift;
    if (open LOG, "<$file.forced") {
        close LOG;
        print "$file.forced exists\n" if $debug;
        return 1;
    } else {
        print "$file.forced does not exists\n" if $debug;
        return 0;
    }
}

sub when_forced {
    my $file = shift;
    if (open LOG, "<$file.forced") {
        $_ = <LOG>;
        chomp($_);
        print "$file.forced contains $_"."\n" if $debug;
        close LOG;
        return $_;
    } else {
        print "$file.forced : $!\n" if $debug;
        return 0;
    }
}

my $l = Webwml::Langs->new();
my %langs = $l->iso_name();
my @langs = $l->names();

$argfile = $ARGV[0] or die "Invalid number of arguments";
die "Invalid number of arguments" unless $ARGV[1];
$arglang = $langs{$ARGV[1]} or die "Invalid lang argument: $ARGV[1]";
$argfile =~ m+(.*)/(.*\.wml)+ or die "pattern does not match";
my ($path, $file) = ($1, $2);

my %file_info = $VCS->file_info($argfile);
my $origrev = $file_info{'cmt_rev'};
unless ($origrev)
{
	die "Could not get revision number for $argfile - bug in script?\n";
}

foreach $lang (@langs) {
    next if ($lang eq $arglang);
    my $transfile = $argfile;
    my ($maxdelta, $mindelta) = (5, 2);
    my ($original, $langrev);
    print "Now checking $lang\n" if $debug;
    $transfile =~ s+$arglang+$lang+ or die "wrong argument: pattern does not match file: $transfile";

    # Parse the translated file
    my $transcheck = Webwml::TransCheck->new($transfile);
    next unless $transcheck->revision();
    $langrev  = $transcheck->revision();
    $original = $transcheck->original();
    $maxdelta = $transcheck->maxdelta() if $transcheck->maxdelta();
    $mindelta = $transcheck->mindelta() if $transcheck->mindelta();
    
    next unless not defined $original or $original eq $arglang;

    $difference = $VCS->count_changes($argfile, $langrev, $origrev);
    if (!defined $difference) {
	die "count_changes failed when looking at $argfile\n";
    }
    if ($difference < $mindelta) {
        next unless was_forced($transfile);
        print "unlinking $transfile.forced\n" if $debug;
        unlink "$transfile.forced";
        next;
    }
    my $forced_at = when_forced($transfile);
    if ($difference < $maxdelta) {
        if ($forced_at != $mindelta) {
            print "difference matches $mindelta, but wasn't rebuilt at $mindelta\n" if $debug;
            rebuild($transfile);
            mark_forced($transfile, $mindelta);
            last;
        }
    } elsif ($forced_at != $maxdelta) {
        print "difference matches $maxdelta, but wasn't rebuilt at $maxdelta\n" if $debug;
        rebuild($transfile);
        mark_forced($transfile, $maxdelta);
        last;
    }
}
