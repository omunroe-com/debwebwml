#!/usr/bin/perl -w

##  Copyright (C) 2001  Denis Barbier <barbier@debian.org>
##
##  This program is free software; you can redistribute it and/or modify
##  it under the terms of the GNU General Public License as published by
##  the Free Software Foundation; either version 2 of the License, or
##  (at your option) any later version.

=head1 NAME

Webwml::Langs - get all languages in which w.b.o is translated

=head1 SYNOPSIS

 use Webwml::Langs;
 my $l = Webwml::Langs->new();
 my @abbr  = $l->iso3166();
 my @langs = $l->names();
 my %lang1 = $l->iso_name();
 my %lang2 = $l->name_iso();

=head1 DESCRIPTION

This module parses english/template/debian/languages.wml and returns 
the list of languages in which Debian web site is translated.

=head1 METHODS

=over 4

=cut

package Webwml::Langs;
use Carp;
use strict;
use Local::Cvsinfo;

=item new

This is the constructor.  If called with an argument, it tells where to
find top-level webwml directory.  Otherwise it is automatically
determined by parsing F<CVS/Repository>.

   my $l = Webwml::Langs->new("/path/to/webwml");

=cut

sub new {
        my $proto = shift;
        my $class = ref($proto) || $proto;
        my $root;
        if (@_) {
                $root = shift;
        } else {
                my $cvs = Local::Cvsinfo->new();
                $cvs->readinfo('.');
                $root = $cvs->topdir()
                        or croak ("Unable to determine top-level directory");
        }
        my $self = _read($root);
        bless ($self, $class);
        return $self;
}

sub _read {
        my $root = shift;
        open(LANGS, "< $root/english/template/debian/languages.wml")
                or croak ("Unable to read $root/english/template/debian/languages.wml");
        my $decl = "";
        my $start = 1;
        #   This variable is declared in english/template/debian/languages.wml
        my %langs;
        while (<LANGS>) {
                next if $_ !~ m/\s*my\s+\%langs\s*=/ and $start;
                next if m/^\s*\#/;
                $start = 0;
                $decl .= $_;
                last if m/\);/;
        }
        close(LANGS);
        $decl =~ s/^\s*my//s;
        eval "$decl";
        carp $@ . " when parsing \n$decl\nin Webwml::Langs\n" if $@;
        return \%langs;
}

=item iso3166

Return the list of country codes.

   my @abbr = $l->iso3166();

=cut

sub iso3166 {
        my $self = shift;
        return values %{$self};
}

=item names

Return the list of language names.

   my @langs = $l->names();

=cut

sub names {
        my $self = shift;
        return keys %{$self};
}

=item iso_name

Return a hash array I<code>/I<name>.

   my %lang1 = $l->iso_name();

=cut

sub iso_name {
        my $self = shift;
        return map { ${$self}{$_} => $_ } keys %$self;
}

=item name_iso

Return a hash array I<name>/I<code>.

   my %lang2 = $l->name_iso();

=cut

sub name_iso {
        my $self = shift;
        return %{$self};
}

=back

=head1 AUTHOR

Copyright (C) 2001  Denis Barbier <barbier@debian.org>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=cut

1;

