#!/bin/bash
infile=$1
outfile=$2

zcat $infile | sed -n '1~4s/^@/>/p;2~4p' |
sed 's/ /:/g' | awk 'BEGIN{OFS=""}{if(NR%2==0){print $0}else{print $0,"/0/","0_",length}}' > $outfile
