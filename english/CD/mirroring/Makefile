# If this makefile is not generic enough to support a translation,
# please contact debian-www.

WMLBASE=../..
CUR_DIR=CD/mirroring
SUBS=

NOGENERICDEP := true

include $(WMLBASE)/Make.lang

# The "| $(VCSREVCACHE)" here is an order-only prerequisite - always
# check that the prerequisite exists and is up to date, but don't
# rebuild everything whenever it's updated - see
# https://www.gnu.org/software/make/manual/html_node/Prerequisite-Types.html
%.$(LANGUAGE).html: %.wml $(WMLRCDEP) $(GETTEXTDEP) $(TEMPLDIR)/cdimage.wml | $(VCSREVCACHE)
	$(WML) $(<F)

rsync-mirrors.$(LANGUAGE).html: rsync-mirrors.wml $(TEMPLDIR)/cdimage.wml \
  $(ENGLISHDIR)/CD/mirroring/cdimage_mirrors.list | $(VCSREVCACHE)

ifeq "$(LANGUAGE)" "en"

$(ENGLISHDIR)/mirror/Mirrors.masterlist:
	$(MAKE) -C $(ENGLISHDIR)/mirror Mirrors.masterlist

$(ENGLISHDIR)/CD/mirroring/cdimage_mirrors.list: \
  $(ENGLISHDIR)/mirror/mirror_list.pl $(ENGLISHDIR)/mirror/Mirrors.masterlist
	$< -m $(word 2,$^) -t cdimages-rsync > $@
endif
