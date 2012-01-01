#!/usr/bin/perl -w
# this script is maintained by Craig Small <csmall@debian.org>.

use strict;
use DBI;

my $header = "# vendors.CD - CD Vendor list
# THIS FILE IS GENERATED BY A SCRIPT, DO NOT EDIT DIRECTLY!!
# See getvendors.pl and/or email csmall\@debian.org if you need to
# change this.

# Id: \$Id\$

#use wml::debian::common_translation
#include \"\$(ENGLISHDIR)/CD/vendors/vendors.CD.def\"

# this is to fix a bug with WML 1.7.4 which makes it very slow on large files
<protect pass=5>

";

my $footer = "\n</protect>\n";


my $dbh = DBI->connect("dbi:Pg:dbname=debianwww", "csmall","");

my $sth = $dbh->prepare("SELECT DISTINCT country FROM debiancd WHERE hidden = 'f'");

my $rv = $sth->execute();

print $header;
my @row;
while ( @row = $sth->fetchrow_array ) {
    my ($country, $cc, $vsth, $vrv, $tmpstr, $cdstr, $dvdstr, $archstr,$sql);
    my @cdtypes;
    my @dvdtypes;
    my @archs;
    my ($name, $email, $url, $urldeb,$contribution,$ship,
        $officialcd, $ocd_nonfree, $ocd_nonus, $ocd_vendor, $ocd_contrib,
        $vendorcd, $vcd_nonfree, $vcd_nonus, $vcd_contrib, $nonuscd,
        $develsscd, $nonfreecd, $contribcd, $customcd,
        $officialdvd, $vendordvd, $develssdvd,
        $arch_alpha, $arch_arm, $arch_hppa, $arch_i386, $arch_ia64, 
        $arch_m68k, $arch_mips, $arch_powerpc, $arch_os390, $arch_sparc, 
        $arch_source, $hurd_i386, $hurd_source);

    $country = $row[0];
    $cc = uc($country);
    print "<hr>\n<h3><a name=\"$country\"><country-name ",$cc,"></a></h3>\n";

    $sql = "SELECT name,email,url,deburl,contribute,ship, ";
    $sql .= "officialcd,ocd_nonfree,ocd_nonus,ocd_vendor,ocd_contrib, ";
    $sql .= "vendorcd,vcd_nonfree,vcd_nonus,vcd_contrib, ";
    $sql .= "nonuscd,develsscd,nonfreecd, contribcd,customcd, ";
    $sql .= "officialdvd, vendordvd, develssdvd, ";
    $sql .= "arch_alpha, arch_arm, arch_hppa, arch_i386, arch_ia64, ";
    $sql .= "arch_m68k, arch_mips, arch_powerpc, arch_os390, arch_sparc, ";
    $sql .= " arch_source, hurd_i386, hurd_source ";
    $sql .= "from debiancd WHERE country='$country' AND hidden = 'f' ORDER BY name";
    $vsth = $dbh->prepare($sql);
    $vrv = $vsth->execute();
    $vsth->bind_columns(\$name, \$email, \$url, \$urldeb,\$contribution,\$ship,
        \$officialcd, \$ocd_nonfree, \$ocd_nonus, \$ocd_vendor, \$ocd_contrib,
        \$vendorcd, \$vcd_nonfree, \$vcd_nonus, \$vcd_contrib, 
        \$nonuscd, \$develsscd, \$nonfreecd, \$contribcd, \$customcd,
        \$officialdvd, \$vendordvd, \$develssdvd,
        \$arch_alpha, \$arch_arm, \$arch_hppa, \$arch_i386, \$arch_ia64,
        \$arch_m68k, \$arch_mips, \$arch_powerpc, \$arch_os390,
        \$arch_sparc, \$arch_source, \$hurd_i386, \$hurd_source);
    while ($vsth->fetch) {
        print "<vendorentry>\n";
        print "    <vendor $name>\n";
        print "    <URL \"$url\">\n";
        print "    <URLdeb \"$urldeb\">\n";
        if ($contribution) {
          print "    <contribution yes>\n";
        } else {
          print "    <contribution no>\n";
        }
        print "    <td>\n";
        print "    <country <country-name ", $cc, ">>\n";
        print "    <ship ";
        if ($ship eq "y") {
            print "yes";
        } elsif ($ship eq 'e') {
            print "europe";
        } elsif ($ship eq 's') {
            print "some";
        } else {
            print "no";
        }
        print ">\n";
        print "    <email $email>\n";
        print "    </TD></TR><TR><TD colspan=\"2\">\n";
        print "    <type> ";
        @cdtypes = ();
        if ($officialcd) {
            $tmpstr = "<OfficialCD>";
            if ($ocd_nonfree) { $tmpstr .= " + <non-free>"; }
            if ($ocd_nonus) { $tmpstr .= " + <non-us>"; }
            if ($ocd_contrib) { $tmpstr .= " + <contrib>"; }
            if ($ocd_vendor) { $tmpstr .= " + <VendorAdditions>"; }
            push @cdtypes, $tmpstr;
        }
        if ($vendorcd) {
            $tmpstr =  "<VendorRelease>";
            if ($vcd_nonfree) { $tmpstr .= " + <non-free>"; }
            if ($vcd_nonus) { $tmpstr .= " + <non-us>"; }
            if ($vcd_contrib) { $tmpstr .= " + <contrib>"; }
            push @cdtypes, $tmpstr;
        }
        if ($customcd) {
            push @cdtypes, "<custom>";
        }
        if ($nonuscd) {
            push @cdtypes, "<non-us>";
        }
        if ($nonfreecd) {
            push @cdtypes, "<non-free>";
        }
        if ($contribcd) {
            push @cdtypes, "<contrib>";
        }
        if ($develsscd) {
            push @cdtypes, "<DevelopmentSnapshot>";
        }
        $cdstr = join ' ; ', @cdtypes;
        print "$cdstr\n";

        if ($officialdvd || $vendordvd || $develssdvd) {
            print "    </TD></TR><TR><TD colspan=\"2\">\n";
            print "    <dvdtype> ";
            @dvdtypes = ();
            if ($officialdvd) {
                push @dvdtypes, "<OfficialCD>";
            }
            if ($vendordvd) {
                push @dvdtypes, "<VendorRelease>";
            }
            if ($develssdvd) {
                push @dvdtypes, "<DevelopmentSnapshot>";
            }
            $dvdstr = join ' ; ', @dvdtypes;
            print "$dvdstr\n";
        }

        print "    </TD></TR><TR><TD colspan=\"2\">\n";
        print "    <architectures> ";
        @archs = ();
        if ($arch_alpha) {
            push @archs, "Alpha";
        }
        if ($arch_arm) {
            push @archs, "ARM";
        }
        if ($arch_hppa) {
            push @archs, "HPPA";
        }
        if ($arch_i386) {
            push @archs, "i386";
        }
        if ($arch_ia64) {
            push @archs, "IA-64";
        }
        if ($arch_m68k) {
            push @archs, "m68k";
        }
        if ($arch_mips) {
            push @archs, "MIPS";
        }
        if ($arch_powerpc) {
            push @archs, "PowerPC";
        }
        if ($arch_os390) {
            push @archs, "S/390";
        }
        if ($arch_sparc) {
            push @archs, "Sparc";
        }
        if ($arch_source) {
            push @archs, "<source>";
        }
        if ($hurd_i386) {
            push @archs, "Hurd-i386";
        }
        if ($hurd_source) {
            push @archs, "Hurd-<source>";
        }
        $tmpstr = join ' ; ',@archs;
        print "$tmpstr\n";


        print "</vendorentry>\n<hr>\n";
    }

}
print $footer;
$sth->finish();
$dbh->disconnect();
