# If this makefile is not generic enough to support a translation,
# please contact debian-www.

WMLBASE=..
CUR_DIR=CD
SUBS=artwork faq http-ftp jigdo-cd torrent-cd mirroring netinst live releases vendors

GETTEXTFILES += cdimage.mo

NOGENERICDEP := true
include $(WMLBASE)/Make.lang

ifeq "$(LANGUAGE)" "en"
     EXTRAWMLDEP := $(WMLRCDEP) $(GETTEXTDEP) $(TEMPLDIR)/cdimage.wml
else
     EXTRAWMLDEP := $(WMLRCDEP) $(GETTEXTDEP) $(TEMPLDIR)/cdimage.wml $(TEMPLDIR)/translation-check.wml
endif

# The "| $(VCSREVCACHE)" here is an order-only prerequisite - always
# check that the prerequisite exists and is up to date, but don't
# rebuild everything whenever it's updated - see
# https://www.gnu.org/software/make/manual/html_node/Prerequisite-Types.html
%.$(LANGUAGE).html: %.wml $(EXTRAWMLDEP) | $(VCSREVCACHE)
	$(WML) $(<F)

ifneq "$(wildcard releases/index.wml)" ""
RELEASESDEP := releases/index.wml
else
RELEASESDEP := $(ENGLISHDIR)/CD/releases/index.wml
endif

index.$(LANGUAGE).html: index.wml $(TEMPLDIR)/cdimage.wml $(TEMPLDIR)/release_info.wml $(RELEASESDEP) $(GETTEXTDEP)
	$(WML) $(<F) -I $(ENGLISHDIR)/CD/

misc.$(LANGUAGE).html: misc.wml $(TEMPLDIR)/cdimage.wml $(GETTEXTDEP)
	$(WML) $(<F)

verify.$(LANGUAGE).html: verify.wml $(TEMPLDIR)/cdimage.wml $(GETTEXTDEP) $(ENGLISHDIR)/CD/CD-keys.data
	$(WML) $(<F)
