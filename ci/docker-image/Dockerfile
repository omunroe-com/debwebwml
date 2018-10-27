FROM debian:stretch
MAINTAINER Wouter Verhelst <wouter@debian.org>
RUN apt-get update
# This creates several layers. This is *ON PURPOSE*. The alternative is
# to have a nearly 2G single layer; pushing that takes multiple hours,
# and pulling that is sloooow too.
RUN apt-get -y install wml make gettext && apt-get clean
RUN apt-get -y install git opencc diffstat && apt-get clean
RUN apt-get -y install libintl-perl libxml-rss-perl wget libtimedate-perl libsoap-lite-perl liblocale-gettext-perl && apt-get clean
RUN apt-get -y install texlive-latex-base texlive-binaries texlive-fonts-recommended && apt-get clean
RUN apt-get -y install debiandoc-sgml python-lxml && apt-get clean
