# If this makefile is not generic enough to support a translation,
# please contact debian-www.

WMLBASE=../../../..
CUR_DIR=devel/debian-nonprofit/News/2003
SUBS=

NOGENERICDEP := true

include $(WMLBASE)/Make.lang

# The "| $(VCSREVCACHE)" here is an order-only prerequisite - always
# check that the prerequisite exists and is up to date, but don't
# rebuild everything whenever it's updated - see
# https://www.gnu.org/software/make/manual/html_node/Prerequisite-Types.html
index.$(LANGUAGE).html: index.wml $(wildcard 2003*.wml) \
                        $(wildcard 2003*.title)\
                        $(TEMPLDIR)/template.wml $(TEMPLDIR)/recent_list.wml | $(VCSREVCACHE)
	$(WML) index.wml
%.$(LANGUAGE).html: %.wml $(TEMPLDIR)/news.wml | $(VCSREVCACHE)
	$(WML) $(<F)
