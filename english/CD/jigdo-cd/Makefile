# If this makefile is not generic enough to support a translation,
# please contact debian-www.

WMLBASE=../..
CUR_DIR=CD/jigdo-cd
SUBS=

NOGENERICDEP := true

include $(WMLBASE)/Make.lang

# The "| $(VCSREVCACHE)" here is an order-only prerequisite - always
# check that the prerequisite exists and is up to date, but don't
# rebuild everything whenever it's updated - see
# https://www.gnu.org/software/make/manual/html_node/Prerequisite-Types.html
%.$(LANGUAGE).html: %.wml $(WMLRCDEP) $(GETTEXTDEP) $(TEMPLDIR)/cdimage.wml | $(VCSREVCACHE)
	$(WML) $(<F)

index.$(LANGUAGE).html: index.wml $(TEMPLDIR)/cdimage.wml \
	$(TEMPLDIR)/installer.wml $(TEMPLDIR)/toc.wml \
	$(TEMPLDIR)/release_info.wml \
	$(ENGLISHSRCDIR)/devel/debian-installer/images.data \
	$(TEMPLDIR)/release_images.wml | $(VCSREVCACHE)
