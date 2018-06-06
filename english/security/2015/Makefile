# If this makefile is not generic enough to support a translation,
# please contact debian-www.

WMLBASE=../..
CUR_DIR=security/2015
SUBS=

GETTEXTFILES += security.mo

NOGENERICDEP := true
include $(WMLBASE)/Make.lang

# The "| $(VCSREVCACHE)" here is an order-only prerequisite - always
# check that the prerequisite exists and is up to date, but don't
# rebuild everything whenever it's updated - see
# https://www.gnu.org/software/make/manual/html_node/Prerequisite-Types.html

%.$(LANGUAGE).html: %.wml $(TEMPLDIR)/security.wml \
  $(ENGLISHSRCDIR)/$(CUR_DIR)/%.data $(GETTEXTDEP) | $(VCSREVCACHE)
	$(WML) $(<F)

index.$(LANGUAGE).html: index.wml \
  $(wildcard dsa-[0-9]*.wml) $(wildcard $(ENGLISHSRCDIR)/$(CUR_DIR)/dsa-[0-9]*.data) \
  $(wildcard dla-[0-9]*.wml) $(wildcard $(ENGLISHSRCDIR)/$(CUR_DIR)/dla-[0-9]*.data) \
  $(TEMPLDIR)/template.wml $(TEMPLDIR)/recent_list_security.wml $(GETTEXTDEP) | $(VCSREVCACHE)
	$(WML) $(<F)
