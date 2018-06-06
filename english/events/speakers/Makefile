# If this makefile is not generic enough to support a translation,
# please contact debian-www.

WMLBASE=../..
CUR_DIR=events/speakers
SUBS=

NOGENERICDEP := true
GETTEXTFILES += newsevents.mo

include $(WMLBASE)/Make.lang

# The "| $(VCSREVCACHE)" here is an order-only prerequisite - always
# check that the prerequisite exists and is up to date, but don't
# rebuild everything whenever it's updated - see
# https://www.gnu.org/software/make/manual/html_node/Prerequisite-Types.html
index.$(LANGUAGE).html: index.wml $(TEMPLDIR)/template.wml \
                        $(ENGLISHSRCDIR)/events/speakers/speakers.data \
                        $(ENGLISHSRCDIR)/events/speakers/speakers.defs \
                        $(GETTEXTDEP) | $(VCSREVCACHE)
	$(WML) $(<F)

%.$(LANGUAGE).html: %.wml $(TEMPLDIR)/speakers.wml | $(VCSREVCACHE)
	$(WML) $(<F)
