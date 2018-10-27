# If this makefile is not generic enough to support a translation,
# please contact debian-www.

WMLBASE=../..
CUR_DIR=international/l10n
SUBS=po po-debconf po4a

GETTEXTFILES += l10n.mo

include $(WMLBASE)/Make.lang

ifeq ($(USE_SAMPLE_FILES),1)
$(ENGLISHSRCDIR)/$(CUR_DIR)/data/%: $(ENGLISHSRCDIR)/$(CUR_DIR)/data/%.sample
	if [ ! -f $@ ]; then cp $< $@; else touch $@; fi

data/popcon: $(ENGLISHSRCDIR)/$(CUR_DIR)/data/popcon
data/unstable: $(ENGLISHSRCDIR)/$(CUR_DIR)/data/unstable
endif
