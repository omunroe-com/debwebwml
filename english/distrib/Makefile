# If this makefile is not generic enough to support a translation,
# please contact debian-www.

WMLBASE=..
CUR_DIR=distrib
SUBS=

GETTEXTFILES = distrib.mo

include $(WMLBASE)/Make.lang

archive.$(LANGUAGE).html: archive.wml $(ENGLISHDIR)/distrib/archive.mirrors \
  $(TEMPLDIR)/countries.wml
packages.$(LANGUAGE).html: packages.wml $(TEMPLDIR)/release_info.wml \
  $(ENGLISHDIR)/distrib/search_packages-form.inc \
  $(ENGLISHDIR)/distrib/search_contents-form.inc \
  $(ENGLISHDIR)/releases/sid/archive.data \
  $(ENGLISHDIR)/releases/arches.data
pre-installed.$(LANGUAGE).html: pre-installed.wml $(TEMPLDIR)/countries.wml \
  $(ENGLISHDIR)/distrib/pre-installed.data $(ENGLISHDIR)/CD/vendors/vendors.CD.def \
  $(ENGLISHDIR)/distrib/pre-installed.defs $(ENGLISHSRCDIR)/distrib/pre-installed.inc

index.$(LANGUAGE).html: index.wml \
  $(TEMPLDIR)/release_info.wml \
  $(TEMPLDIR)/release_images.wml \

netinst.$(LANGUAGE).html: netinst.wml \
  $(TEMPLDIR)/toc.wml \
  $(TEMPLDIR)/release_info.wml \
  $(TEMPLDIR)/release_images.wml \

ifeq "$(LANGUAGE)" "en"
$(ENGLISHSRCDIR)/distrib/pre-installed.inc: pre-installed.data count
	$(ENGLISHSRCDIR)/distrib/count

clean::
	rm -f archive.mirrors

$(ENGLISHSRCDIR)/mirror/Mirrors.masterlist:
	$(MAKE) -C $(ENGLISHSRCDIR)/mirror/Mirrors.masterlist

$(ENGLISHSRCDIR)/distrib/archive.mirrors: \
 $(ENGLISHSRCDIR)/mirror/Mirrors.masterlist $(ENGLISHSRCDIR)/mirror/mirror_list.pl
	echo "#use wml::debian::countries" > $@
	echo "<define-tag archivemirrors>" >> $@
	echo "<ul>" >> $@
	../mirror/mirror_list.pl -m ../mirror/Mirrors.masterlist -t compact-old >> $@
	echo "</ul>" >> $@
	echo "</define-tag>" >> $@

.DELETE_ON_ERROR:

endif
