#!/bin/bash
infile=$1
outfile=$2

zcat $infile | sed -n '1~4s/^@/>/p;2~4p' > $outfile
