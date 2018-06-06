# If this makefile is not generic enough to support a translation,
# please contact debian-www.

WMLBASE=../..
CUR_DIR=devel/wnpp
SUBS=

GETTEXTFILES += wnpp.mo

NOGENERICDEP = true
include $(WMLBASE)/Make.lang

clean::
	rm -f $(DATADIR)/wnpp.data

DATADIR = $(ENGLISHSRCDIR)/$(CUR_DIR)

# The "| $(VCSREVCACHE)" here is an order-only prerequisite - always
# check that the prerequisite exists and is up to date, but don't
# rebuild everything whenever it's updated - see
# https://www.gnu.org/software/make/manual/html_node/Prerequisite-Types.html
%.$(LANGUAGE).html: %.wml $(TEMPLDIR)/template.wml $(TEMPLDIR)/languages.wml \
  $(WMLBASE)/../.wmlrc $(WMLBASE)/.wmlrc $(DATADIR)/wnpp.data \
  $(GETTEXTDEP) | $(VCSREVCACHE)
	$(WML) $(<F)

$(DATADIR)/wnpp.data: WMLOUTFILE=$(DATADIR)/wnpp.data
$(DATADIR)/wnpp.data:
	$(WML) -W7,-Squotes $(DATADIR)/wnpp.pl

ifeq "$(LANGUAGE)" "en"
.PHONY: $(DATADIR)/wnpp.data
.DELETE_ON_ERROR: $(DATADIR)/wnpp.data
endif

MAKE_LINK =  [ -f $(2).wml ] && [ ! -f $(HTMLDIR)/$(1).$(LANGUAGE).html ] && \
		ln -sf $(2).$(LANGUAGE).html $(HTMLDIR)/$(1).$(LANGUAGE).html \
			|| true

install::
	$(call MAKE_LINK,o,orphaned)
	$(call MAKE_LINK,rfa,rfa_bypackage)
	$(call MAKE_LINK,ita,being_adopted)
	$(call MAKE_LINK,rfh,help_requested)
	$(call MAKE_LINK,itp,being_packaged)
	$(call MAKE_LINK,rfp,requested)
