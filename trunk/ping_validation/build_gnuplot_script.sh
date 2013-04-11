TSTAT_OUT_FOLDER=$1
PING_SCRIPT=$2


#Get the latest analysis
LAST_RUN_FOLDER=/tmp/tstat_out/`ls -Artl $TSTAT_OUT_FOLDER | tail -n1 | tr -s ' ' | cut -f9 -d' '`
WIN_ACK_TRIG_FILE=$LAST_RUN_FOLDER/log_tcp_windowed_qd_acktrig
WIN_DATA_TRIG_FILE=$LAST_RUN_FOLDER/log_tcp_windowed_qd_datatrig
SAMPLE_ACK_TRIG_FILE=$LAST_RUN_FOLDER/log_tcp_qd_sample_acktrig

#Setting gnuplot instructions
#see: http://hxcaine.com/blog/2013/02/28/running-gnuplot-as-a-live-graph-with-automatic-updates/

#to print both graphs
echo -ne "reset;\n" > $PING_SCRIPT
echo -ne "set grid; show grid; set xlab 'timestamp';\n" >> $PING_SCRIPT
echo -ne "set format x \"%10.0f\";" >> $PING_SCRIPT
echo -ne "set ylab '[ms]'; set ytics nomirror; \n" >> $PING_SCRIPT
echo -ne "set tmargin 0; set bmargin 0; set lmargin 10; set rmargin 10;" >> $PING_SCRIPT

#I want my graphs be placesd in 2 rows and 1 column. I ask for 3 plots (although
#I need only 2 plots) in order to gain space
#See gnuplot.sourceforge.net/demo/layout.html
echo -ne "set multiplot layout 3,1;\n" >> $PING_SCRIPT

echo -ne "unset xtics;" >> $PING_SCRIPT
echo -ne "plot " >> $PING_SCRIPT

#echo -ne "'< cat $WIN_ACK_TRIG_FILE' u 1:(\$11) with linespoints axes x1y1 title 'data2ack_C2S' " >> $PING_SCRIPT
#echo -ne ", '< cat $WIN_ACK_TRIG_FILE' u 1:(\$24) with linespoints axes x1y1 title 'data2ack_S2C'," >> $PING_SCRIPT

echo -ne "'< cat $WIN_ACK_TRIG_FILE' u 1:(\$7) with linespoints axes x1y1 title 'ack_trig_windowed_qd_C2S'" >> $PING_SCRIPT

echo -ne ", '< cat $WIN_ACK_TRIG_FILE' u 1:(\$20) with linespoints axes x1y1 title 'ack_trig_windowed_qd_S2C'" >> $PING_SCRIPT

echo -ne ", '< cut -d= -f4- /tmp/ping.DATA' u 1:3 with linespoints axes x1y1 title 'rtt_ping';\n" >> $PING_SCRIPT
echo -ne "set xrange [GPVAL_X_MIN:GPVAL_X_MAX];\n" >> $PING_SCRIPT

echo -ne "set ylab 'validity ratio'; set y2lab 'no samples/window'; set ytics nomirror; set y2tics;\n" >> $PING_SCRIPT
echo -ne "set xtics nomirror rotate by -90;\n" >> $PING_SCRIPT

echo -ne "plot " >> $PING_SCRIPT

#echo -ne "'< cat $WIN_ACK_TRIG_FILE' u 1:(\$13) with linespoints axes x1y2 title 'no qd_samples_C2S'," >> $PING_SCRIPT

echo -ne "'< cat $WIN_ACK_TRIG_FILE' u 1:(\$26) with linespoints axes x1y2 title 'no qd_samples_S2C'" >> $PING_SCRIPT


#echo -ne ", '< cat $WIN_ACK_TRIG_FILE' u 1:($13/\$10) with linespoints axes x1y1 title 'validity_ratio_C2S'" >> $PING_SCRIPT

echo -ne ", \"< awk '{if(\$23>0) print \$1,\$26/\$23 }' $WIN_ACK_TRIG_FILE\" u 1:2 with linespoints axes x1y1 title 'validity_ratio_S2C';\n" >> $PING_SCRIPT

#To be sure that the 2 graphs have exactly the same ticks
echo -ne "set xrange [GPVAL_X_MIN:GPVAL_X_MAX];\n" >> $PING_SCRIPT

echo -ne "pause 2; reread;\n" >> $PING_SCRIPT
