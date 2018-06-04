# If this makefile is not generic enough to support a translation,
# please contact debian-www.

WMLBASE=../..
THIS_YEAR=1997
include ../Make.year

ifeq "$(LANGUAGE)" "en"
$(HTMLDIR)/common_library $(HTMLDIR)/linux_press_book.txt: $(HTMLDIR)/%: %
	@test -d $(HTMLDIR) || mkdir -m g+w -p $(HTMLDIR)
	install -m 664 -p $< $(HTMLDIR)

install:: $(HTMLDIR)/common_library $(HTMLDIR)/linux_press_book.txt
endif
