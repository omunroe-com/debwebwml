#!/usr/bin/perl -pi

s|^(<HTML lang="zh)">|$1-CN">|;
s|^(<META http-equiv=.*charset)=Big5">|$1=GB2312">|;
s/(\.zh)(?=\.(?:gif|jpg|png))/$1-cn/g;
s|^<A href=".*">(中文&nbsp;\(GB\))</A>(?=&nbsp;)|$1|;

# 先把全部「著」字转为「着」……
while (s/^((?:[\x00-\x7F]|[\x80-\xFF].)*)著/$1着/) {}

# 然后再在适当的词语，把「着」字转回「著」……
#	著作、著者、著名、著述、著重、著书
#	所著、土著、显著、编著
while (s/^((?:[\x00-\x7F]|[\x80-\xFF].)*(?:所|土|显|编))着/$1著/) {}
while (s/^((?:[\x00-\x7F]|[\x80-\xFF].)*)着(?=作|者|名|述|重|书)/$1著/) {}


# s/\<s\<(.+?)\>\>/$1/g;
# s/\<t\<文件\>\>/文档/g;
# s/\<t\<延伸\>\>/扩展/g;


s/软件套件/软件包/g; s/套件/软件包/g;
s/(?:启|起)动磁碟/引导盘/g;
while (s/^((?:[\x00-\x7F]|[\x80-\xFF].)*)—/$1─/) {}
while (s/^((?:[\x00-\x7F]|[\x80-\xFF].)*)「/$1“/) {}
while (s/^((?:[\x00-\x7F]|[\x80-\xFF].)*)」/$1”/) {}
while (s/^((?:[\x00-\x7F]|[\x80-\xFF].)*)『/$1“/) {}
while (s/^((?:[\x00-\x7F]|[\x80-\xFF].)*)』/$1”/) {}
while (s/^((?:[\x00-\x7F]|[\x80-\xFF].)*)相容/$1兼容/) {}
while (s/^((?:[\x00-\x7F]|[\x80-\xFF].)*)电脑/$1计算机/) {}
while (s/^((?:[\x00-\x7F]|[\x80-\xFF].)*)模组/$1模块/) {}
while (s/^((?:[\x00-\x7F]|[\x80-\xFF].)*)支援/$1支持/) {}
while (s/^((?:[\x00-\x7F]|[\x80-\xFF].)*)字型/$1字体/) {}
while (s/^((?:[\x00-\x7F]|[\x80-\xFF].)*(软|硬))体/$1件/) {}
while (s/^((?:[\x00-\x7F]|[\x80-\xFF].)*(软|硬|光|磁|Zip ))碟/$1盘/) {}
while (s/^((?:[\x00-\x7F]|[\x80-\xFF].)*)以太(?=网)/$1乙太/) {}
while (s/^((?:[\x00-\x7F]|[\x80-\xFF].)*)阐道/$1网关/) {}

# Darn, Perl 5.004 doesn't support (?<=...) or (?<!...)
# while (s/^((?:[\x00-\x7F]|[\x80-\xFF].)*)(?<!方)程式/$1程序/) {}

while (s/^((?:[\x00-\x7F]|[\x80-\xFF].)*)程式/$1程序/) {}

s/通信论坛/邮件列表/g;
s/发行情报/发行信息/g;
s/作业系统/操作系统/g;
s/视窗系统/窗口系统/g;
s/映射站台/镜像站点/g;
s/映射站/镜像站/g;
s/伺服器/服务器/g;
s/(纯)?文字档(案)?/文本文件/g;
s/文字(?=模式|编辑|处理)/文本/g;
s/档案管理员/文件管理器/g;
s/档案系统/文件系统/g;
s/预设值/缺省值/g;
s/列表机/打印机/g;
s/记忆体/内存/g;
s/字元提示器/提示符/g;
s/设定档(?:案)?/配置文件/g;
s/档案名称/文件名/g;
