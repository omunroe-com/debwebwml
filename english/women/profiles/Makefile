# If this makefile is not generic enough to support a translation,
# please contact debian-www.

WMLBASE=../..
CUR_DIR=women/profiles
SUBS=pictures
PROFILES := $(filter-out index.wml, $(wildcard *.wml))
## GETTEXTFILES += others.mo

NOGENERICDEP := true
include $(WMLBASE)/Make.lang

# The "| $(VCSREVCACHE)" here is an order-only prerequisite - always
# check that the prerequisite exists and is up to date, but don't
# rebuild everything whenever it's updated - see
# https://www.gnu.org/software/make/manual/html_node/Prerequisite-Types.html
index.$(LANGUAGE).html : index.wml $(WMLRCDEP) $(GETTEXTDEP) \
  $(PROFILES) \
  $(TEMPLDIR)/users_list.wml \
  $(TEMPLDIR)/template.wml $(TEMPLDIR)/languages.wml | $(VCSREVCACHE)
	$(WML) $(<F)
ifeq "$(LANGUAGE)" "en"
	$(IGNORE)$(WMLBASE)/../touch_translations.pl $(CURDIR)/$(<F) $(LANGUAGE)
else
ifneq "$(findstring international,$(CUR_DIR))" ""
	$(IGNORE)$(WMLBASE)/../touch_translations.pl $(CURDIR)/$(<F) $(LANGUAGE)
endif
endif

%.$(LANGUAGE).html : %.wml $(WMLRCDEP) $(GETTEXTDEP) \
  $(ENGLISHSRCDIR)/women/profiles/profiles.def \
  $(TEMPLDIR)/faqs.wml \
  $(TEMPLDIR)/profiles.wml \
  $(TEMPLDIR)/template.wml $(TEMPLDIR)/languages.wml | $(VCSREVCACHE)
	$(WML) $(<F)
ifeq "$(LANGUAGE)" "en"
	$(IGNORE)$(WMLBASE)/../touch_translations.pl $(CURDIR)/$(<F) $(LANGUAGE)
else
ifneq "$(findstring international,$(CUR_DIR))" ""
	$(IGNORE)$(WMLBASE)/../touch_translations.pl $(CURDIR)/$(<F) $(LANGUAGE)
endif
endif
