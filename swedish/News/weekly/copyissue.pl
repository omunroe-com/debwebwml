#!/usr/bin/perl -w

# This script copies a DWN issue as given on the command line to the
# translation named in copypage.conf, translates a few strings,
# adds the translation-check header to it. It will also create the
# destination directory if necessary.

# Written in 2000-2002 by peter karlsson <peter@softwolves.pp.se>
# � Copyright 2000-2002 Software in the public interest, Inc.
# This program is released under the GNU General Public License, v2.

# $Id$

# Get command line
($year, $issue) = @ARGV;

# Check usage.
unless ($year && $issue)
{
	print "Usage: $0 year issue\n\n";
	print "Copies the issue from the English directory to the local one and adds\n";
	print "the translation-check header\n";
	exit;
}

# Create needed file and directory names
$srcdir = "../../../english/News/weekly/$year/$issue";
$srcfile= "$srcdir/index.wml";
$cvsfile= "$srcdir/CVS/Entries";
$yeardir= "./$year";
$dstdir = "./$year/$issue";
$dstfile= "$dstdir/index.wml";

# Sanity checks
die "Directory $srcdir does not exist\n" unless -d $srcdir;
die "File $srcfile does not exist\n"     unless -e $srcfile;
die "File $dstfile already exists\n"     if     -e $dstfile;
mkdir $yeardir, 0755                     unless -d $yeardir;
mkdir $dstdir, 0755                      unless -d $dstdir;

# Open the files
open CVS, $cvsfile
	or die "Could not read $cvsfile ($!)\n";

open SRC, $srcfile
	or die "Could not read $srcfile ($!)\n";

open DST, ">$dstfile"
	or die "Could not create $dstfile ($!)\n";

# Retrieve the CVS version number
while (<CVS>)
{
	if (m[^/index\.wml/([0-9]*\.[0-9])*/]o)
	{
		$revision = $1;
	}
}

close CVS;

unless ($revision)
{
	print "Could not get revision number\n";
	$revision = '1.1';
}

# Copy the file, translate date and some other stuff, and insert the
# revision number
$insertedrevision = 0;

while (<SRC>)
{
	if ($_ eq "<b>Welcome</b> to Debian Weekly News, a newsletter for the Debian developer\n")
	{
		# Translate intro
		$next = <SRC>;
		if ($next eq "community.\n")
		{
			$_ = "<b>V�lkommen</b> till Debian Weekly News, ett nyhetsbrev f�r Debianutvecklare.\n";
		}
		else
		{
			$_ .= $next;
		}
	}
	elsif ($_ eq "<b>Welcome</b> to Debian Weekly News, a newsletter for the Debian community.\n")
	{
		# Translate intro
		$_ = "<b>V�lkommen</b> till Debian Weekly News, ett nyhetsbrev f�r Debianfolk.\n";
	}
	elsif ($_ eq "<p><strong>New or Noteworthy Packages.</strong> The following new or\n")
	{
		# Translate new files intro
		$next = <SRC>;
		if ($next eq "updated packages were added to the Debian archive since our last\n")
		{
			$next2 = <SRC>;
			if ($next2 eq "issue.</p>\n")
			{
				$_ =  "<p><strong>Nya eller anm�rkningsv�rda paket.</strong>\n";
				$_ .= "F�ljande paket har lagts till Debianarkivet sedan f�rra utg�van.</p>\n";
			}
			else
			{
				$next .= $next2;
				$_ .= $next;
			}
		}
		elsif ($next eq "updated packages were updated or added to the Debian archive recently.</p>\n")
		{
			$_ =  "<p><strong>Nya eller anm�rkningsv�rda paket.</strong\n";
			$_ .= "F�ljande nya eller uppdaterade paket har nyligen lagts till\n";
			$_ .= "Debianarkivet.</p>\n";
		}
		else
		{
			$_ .= $next;
		}
	}
	elsif ($_ eq "<p><strong>Security Updates.</strong> You know the drill, make sure\n")
	{
		# Translate security intro
		$next = <SRC>;
		if ($next eq "you update your systems if you have one of these packages installed.</p>\n")
		{
			$_ = "<p><strong>S�kerhetsuppdatering.</strong>\n";
			$_ = "Du kan rutinen, se till att uppdatera ditt system om du har n�got av\n";
			$_ = "dessa paket installerade.</p>\n";
		}
		else
		{
			$_ .= $next;
		}
	}

	unless ($insertedrevision || /^#/)
	{
		print DST qq'#use wml::debian::translation-check translation="$revision"\n';
		$insertedrevision = 1;
	}
	print DST $_;
}

close SRC;
close DST;

# We're done
print "Copying done, remember to edit $dstfile\n";
