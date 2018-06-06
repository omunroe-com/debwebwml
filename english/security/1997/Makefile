# If this makefile is not generic enough to support a translation,
# please contact debian-www.

WMLBASE=../..
CUR_DIR=security/1997
SUBS=

NOGENERICDEP := true
include $(WMLBASE)/Make.lang


# The "| $(VCSREVCACHE)" here is an order-only prerequisite - always
# check that the prerequisite exists and is up to date, but don't
# rebuild everything whenever it's updated - see
# https://www.gnu.org/software/make/manual/html_node/Prerequisite-Types.html
index.$(LANGUAGE).html: index.wml $(wildcard [0-9]*.wml) \
  $(wildcard $(ENGLISHSRCDIR)/$(CUR_DIR)/[0-9]*.data) \
  $(TEMPLDIR)/template.wml $(TEMPLDIR)/recent_list.wml | $(VCSREVCACHE)
	$(WML) $(<F)

%.$(LANGUAGE).html: %.wml $(ENGLISHSRCDIR)/$(CUR_DIR)/%.data \
  $(TEMPLDIR)/security.wml | $(VCSREVCACHE)
	$(WML) $(<F)
