#!/bin/sh

RESULT_FOLDER=$1
PING_SCRIPT=$2

#Setting gnuplot instructions
#see: http://hxcaine.com/blog/2013/02/28/running-gnuplot-as-a-live-graph-with-automatic-updates/

#to print both graphs
echo "reset;" > $PING_SCRIPT
echo "set grid; show grid; set xlab 'flows';" >> $PING_SCRIPT
echo "set ylab 'MB'; set ytics nomirror;" >> $PING_SCRIPT
echo "set tmargin 0; set bmargin 0; set lmargin 10; set rmargin 10;" >> $PING_SCRIPT

#I want my graphs be placesd in 2 rows and 1 column. I ask for 3 plots (although
#I need only 2 plots) in order to gain space
#See gnuplot.sourceforge.net/demo/layout.html
echo "set multiplot layout 3,1;" >> $PING_SCRIPT

echo "unset xtics;" >> $PING_SCRIPT

echo "plot '< cat $RESULT_FOLDER/Makefile.conf.1.results.txt' u 4:(\$3/1000000) with points axes x1y1 title 'config 1', '< cat $RESULT_FOLDER/Makefile.conf.2.results.txt' u 4:(\$3/1000000) with points axes x1y1 title 'config 2' >> $PING_SCRIPT


echo "set xrange [GPVAL_X_MIN:GPVAL_X_MAX];" >> $PING_SCRIPT

echo "set ylab 'running time (s)'; set ytics nomirror;" >> $PING_SCRIPT
echo "set xtics nomirror rotate by -90;" >> $PING_SCRIPT

echo "plot '< cat $RESULT_FOLDER/Makefile.conf.1.results.txt' u 4:(\$2) with points axes x1y2 title 'config 1', '< cat $RESULT_FOLDER/Makefile.conf.2.results.txt' u 4:(\$2) with points axes x1y2 title 'config 2', '< cat $RESULT_FOLDER/Makefile.conf.3.results.txt' u 4:(\$2) with points axes x1y2 title 'config 3', '< cat $RESULT_FOLDER/Makefile.conf.4.results.txt' u 4:(\$2) with points axes x1y2 title 'config 4';" >> $PING_SCRIPT

#To be sure that the 2 graphs have exactly the same ticks
echo "set xrange [GPVAL_X_MIN:GPVAL_X_MAX];" >> $PING_SCRIPT
echo "pause 2; reread;\n" >> $PING_SCRIPT
