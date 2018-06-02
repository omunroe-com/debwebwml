#!/usr/bin/perl

# This script walks the webwml tree to look for translated files. It
# looks for the wml::debian::translation-check header to see if a file
# is a stranslation of an original, then checks for the revision
# status of the master document.
#
# Part of the effort to switch from CVS to Git
#
# Originally written 2018 by Steve McIntyre <93sam@debian.org>
# © Copyright 2018 Software in the public interest, Inc.
# This program is released under the GNU General Public License, v2.

use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use File::Spec::Functions;
use File::Find;
use lib ($0 =~ m|(.*)/|, $1 or ".") ."/Perl";
use Webwml::TransCheck;
use Local::VCS;

my $help = 0;
my $verbose = 0;
my $dry_run = 0;
my $revs_file = "";
my $db_file = "";
my %rev_map;
my $VCS = Local::VCS->new();

sub usage {
        print <<'EOT';
Usage: switch_to_git_translations.pl [options]
Options:
  --help         display this message
  --verbose      run verbosely
  --dry-run      do not modify translation-check headers
  --revisions=REVISIONS  location of the cvs2git revisions map file
  --db=DB        location of a single translated_txt.db to update, *instead* of
	         scanning for translation-check headers

Find all wml/src/etc. files under the current directory, updating revisions for
translations.
EOT
        exit(0);
}

# log very verbose messages
sub vvlog {
    if ($verbose >= 2) {
	print STDOUT $_[0] . "\n";
    }
}

# log verbose messages
sub vlog {
    if ($verbose >= 1) {
	print STDOUT $_[0] . "\n";
    }
}

# Parse the revisions file for use, building a hash of the git and cvs versions for each file
sub parse_revisions
{
    my $revs_file = shift;
    open(IN, "<", "$revs_file") or die "Can't open revisions file \$revs_file\" for reading: $!\n";
    while (my $line = <IN>) {
	chomp $line;
	my ($file, $cvs_ver, $commit_hash);
	if ($line =~ m,^(\S+) ([.\d]+) ([[:xdigit:]]+)$,)
	{
	    $file = $1;
	    $cvs_ver = $2;
	    $commit_hash = $3;
	    $rev_map{"$file"}{"$cvs_ver"}{"commit_hash"} = $commit_hash;
	} else {
	    die "Failed to parse revisions file at line $.\n";
	}
	vvlog("Found file $file with CVS version $cvs_ver in commit hash $commit_hash");
    }
    close IN;
    vlog("Parsed revisions file \"$revs_file\", found revisions for " . scalar(keys %rev_map) . " files");
}

# return a list of filenames with the given extension
sub find_files_ext
{
    my $dir = shift or die('Internal error: No dir specified');
    my $ext = shift or die('Internal error: No ext specified');

    my @files;
    find( sub { if (-f and m/\.$ext$/) { my $filename = $File::Find::name; $filename =~ s,\.\/,,; push @files, $filename }}, $dir );
    return @files;
}

# Update the translation-check metadata header in a wml file
sub update_file_metadata
{
    my $file = shift;
    my $revision = shift;
    my $hash = shift;
    my $text = "";

    open (IN, "< $file") or die "Can't open $file for reading: $!\n";
    while (<IN>) {
	if (m/^#use wml::debian::translation-check/) {
	    s/(translation="?)($revision)("?)/$1$hash$3/;
	}
	$text .= $_;
    }
    close(IN);
    open(OUT, "> $file") or die "Can't open $file for writing: $!\n";
    print OUT $text;
    close OUT;
}

# Parse a file, and see if there's a translation-check header. If so,
# use the rev_map data to switch the translation information from the
# cvs version to the git hash *if available*. If it's not available,
# report an error.
sub parse_file
{
    my $file = shift;
    my $info = 0; # Do we have any translation header info at all?
    my $tc = Webwml::TransCheck->new("$file") or die "Failed transcheck: $!\n";
    vlog("Looking at wml file $file");
    my $target_lang = "english";
    my $maint = $tc->maintainer();
    if (defined($maint)) {
	vvlog("  Maintainer: $maint");
	$info += 1;
    }
    my $revision = $tc->revision();
    if (defined($revision)) {
	vvlog("  Revision: $revision");
	$info += 1;
    }
    my $original = $tc->original();
    if (defined($original)) {
	vvlog("  Original: $original");
	$info += 1;
	$target_lang = $original;
    }
    my $mindelta = $tc->mindelta();
    if (defined($mindelta)) {
	vvlog("  Mindelta: $mindelta");
	$info += 1;
    }
    my $maxdelta = $tc->maxdelta();
    if (defined($maxdelta)) {
	vvlog("  Maxdelta: $maxdelta");
	$info += 1;
    }
    if ($info > 0) {
	my $targetfile = $file;
	$targetfile =~ s,^[^/]+,$target_lang,;
	vvlog("  Depends on $targetfile");
	if (defined($revision)) {
	    # Do we have a cvs->git map for that file and revision?
	    my $hash = $rev_map{"$targetfile"}{"$revision"}{"commit_hash"};
#	    my $file_hash = $rev_map{"$targetfile"}{"$revision"}{"file_hash"};
	    if (defined $hash) {
#		if (!defined $file_hash) {
#		    $file_hash = `git ls-tree -r $hash $targetfile`;
#		    if ($file_hash =~ m/^\s*\d+\s*blob\s+([[:xdigit:]]+)\s+\S+$/) {
#			$file_hash = $1;
#		    }
#		    # Cache the result
#		    $rev_map{"$targetfile"}{"$revision"}{"file_hash"} = $file_hash;
#		}
		vlog("  Depends on $targetfile with cvs rev $revision, commit hash $hash");
	    } else {
		vlog("  Looking up $targetfile with cvs rev $revision, no mapping found");
		return 1;
	    }
	    if (!$dry_run) {
		vlog ("  Updating the file data");

		update_file_metadata($file, $revision, $hash);
	    }
	} else {
	    vlog("  But no revision data!");
	    return 1;
	}
    }
}

#    open(IN, "<", "$file") or die "Can't open file \$wml_file\" for reading: $!#\n";
#    while (my $line = <IN>) {
#	chomp $line;
#	if ($line =~ m/^#use wml::debian::translation-check/) {
#	    my $original="english"; # default
#	}
#    }
#}

# "main"

if (not GetOptions ("help"      => \$help,
		    "verbose=i" => \$verbose,
		    "dry-run"   => \$dry_run,
		    "db=s"      => \$db_file,
		    "revisions=s" => \$revs_file))
{
        warn "Try `$0 --help' for more information.\n";
        exit(1);
}

if ($help) {
    usage();
}

if (! -f $revs_file) {
    die "Can't open revisions file, abort!\n";
}
parse_revisions($revs_file);

if (length($db_file) < 2) {
    # Mode 1 - scan for files which need translation-check header
    # updates
    my @wmlfiles = sort(find_files_ext(".", 'wml'));
    my @incfiles = sort(find_files_ext(".", 'inc'));
    my @pofiles = sort(find_files_ext(".", 'po'));
    my @srcfiles = sort(find_files_ext(".", 'src'));
    my @files;
    push @files, @wmlfiles;
    push @files, @incfiles;
    push @files, @pofiles;
    push @files, @srcfiles;
    vlog("Found " . scalar(@files) . " files to work on\n");
    for my $file (@files) {
	parse_file($file);
    }
} else {
    my %translated_files;
    # Mode 2 - update a single translated_txt.db file
    if (! -f $db_file) {
	die "Can't find $db_file, abort!\n";
    }
    open IN, "< $db_file" or die "Couldn't open $db_file: $!";
    my $language;
    $db_file =~ m,^([^/]*)/, and $language = $1;
    vlog("working on $db_file, language $language\n");
    while (my $line = <IN>)
    {
	if (($line =~ m%^([A-Za-z0-9\/\.\-\_]*)[\ \t]*([0-9]+\.[0-9]+)$%)
	    and (-f "$language/$1"))
	{
	    $translated_files{$1} = $2;
	}
    }
    close IN;
    my $num_trans = scalar(keys %translated_files);
    vlog("Parsed $db_file, found revisions for $num_trans translations\n");
    vlog("Caching repo for performance...");
    $VCS->cache_repo();
    vlog(" ...done");
    if (!$dry_run) {
	vlog ("  Rewriting $db_file with git revisions");
	open OUT, "> $db_file" or die "Couldn't write $db_file: $!";
	for my $file (sort keys %translated_files) {
	    my $targetfile = "english/$file";
	    my $revision = $translated_files{$file};
	    my $hash = $rev_map{"$targetfile"}{"$revision"}{"commit_hash"};
	    if (!defined $hash) {
		print "Can't find a hash for $targetfile revision $revision\n";
		$hash = $VCS->get_newest_revision($targetfile);
		print "Most recent revision is $hash, using that instead\n";
	    } else {
		printf OUT "%-64s  %s\n", $file, $hash;
	    }
	}
	close OUT;
    }
}
