# If this makefile is not generic enough to support a translation,
# please contact debian-www.

WMLBASE=../..
CUR_DIR=events/2012
SUBS=

GETTEXTFILES += newsevents.mo

NOGENERICDEP := true
include $(WMLBASE)/Make.lang

EVENTFILES := $(wildcard [0-9]*\-*.wml)
ICSFILES := $(filter-out %-report.wml,$(EVENTFILES))
ICSFILES := $(ICSFILES:.wml=.$(LANGUAGE).ics)
DESTICSFILES := $(patsubst %.ics,$(HTMLDIR)/%.ics,$(ICSFILES))

all:: $(ICSFILES)

install:: $(DESTICSFILES)

clean::
	rm -f *.$(LANGUAGE).ics

# The "| $(VCSREVCACHE)" here is an order-only prerequisite - always
# check that the prerequisite exists and is up to date, but don't
# rebuild everything whenever it's updated - see
# https://www.gnu.org/software/make/manual/html_node/Prerequisite-Types.html
index.$(LANGUAGE).html: index.wml $(wildcard [0-9]*\-*.wml) $(TEMPLDIR)/template.wml $(TEMPLDIR)/recent_list.wml | $(VCSREVCACHE)

%.$(LANGUAGE).html: %.wml $(TEMPLDIR)/event.wml | $(VCSREVCACHE)
	$(WML) $(<F)

%.$(LANGUAGE).ics: %.wml $(ENGLISHSRCDIR)/events/make_ics.pl
	$(ENGLISHSRCDIR)/events/make_ics.pl $< $@

$(HTMLDIR)/%.ics: %.ics
	@echo copying $< to $(HTMLDIR)
	-@install -m 644 -p $< $(HTMLDIR)
