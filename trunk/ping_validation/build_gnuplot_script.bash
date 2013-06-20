#!/bin/bash

#### author: andrea.araldo@gmail.com


# All the environment variables used here, are taken from the script included 
# in the next line
source $TSTAT_FOLDER/ping_validation/exp2-netbook-variables_conf.sh

PLOT_FILENAME=$GENERAL_OUT_FOLDER/plot.eps
echo "The file $PLOT_FILENAME will be generated"

#Get the latest analysis
LAST_RUN_FOLDER=$TSTAT_OUT_FOLDER/`ls -Artl $TSTAT_OUT_FOLDER | tail -n1 | tr -s ' ' | cut -f9 -d' '`
WIN_ACK_TRIG_FILE=$LAST_RUN_FOLDER/log_tcp_windowed_qd_acktrig
WIN_DATA_TRIG_FILE=$LAST_RUN_FOLDER/log_tcp_windowed_qd_datatrig
SAMPLE_ACK_TRIG_FILE=$LAST_RUN_FOLDER/log_tcp_qd_sample_acktrig

#tstat log binding
ACK_TRIG_WINDOWED_QD_C2S_COL=9
ACK_TRIG_WINDOWED_QD_S2C_COL=22
NO_QD_SAMPLES_S2C_COL=28
CHANCES_IN_WIN_S2C_COL=25 # In the case of ack triggered analysis, this column indicates the 
						# number of acks received, either valid or not
						
# Get the first timestamp of the experiment
FIRST_TIME=`cut -d"." -f1 $PING_OUT_FILE | head --lines 2 | tail --lines 1`

echo "###### This gnuplot script is automatically produced by launching ping_validation/exp2-netbook-offline-plotting.bash" > $PING_SCRIPT

#To print both graphs, set gnuplot following:
#see: http://hxcaine.com/blog/2013/02/28/running-gnuplot-as-a-live-graph-with-automatic-updates/


echo -ne "reset;\n" >> $PING_SCRIPT

# Set the output image (see www.gnuplotting.org/output-terminals)
echo -ne "set terminal postscript eps enhanced color font 'Helvetica,10';\n" >> $PING_SCRIPT
echo -ne "set output '$PLOT_FILENAME';\n" >> $PING_SCRIPT


echo -ne "set grid; show grid;\n" >> $PING_SCRIPT
echo -ne "set xlab ' ';\n" >> $PING_SCRIPT
echo -ne "set format x \"%10.0f\";" >> $PING_SCRIPT
echo -ne "set ylab '[ms]'; set ytics nomirror; \n" >> $PING_SCRIPT
echo -ne "set tmargin 0; set bmargin 0; set lmargin 10; set rmargin 10;" >> $PING_SCRIPT

#I want my graphs be placesd in 2 rows and 1 column. I ask for 3 plots (although
#I need only 2 plots) in order to gain space
#See gnuplot.sourceforge.net/demo/layout.html
echo -ne "set multiplot layout 3,1;\n" >> $PING_SCRIPT

# I want x tics but not xlabels (ref: http://gnuplot.10905.n7.nabble.com/tics-without-name-tp4595p4596.html)
#echo -ne "unset xtics;" >> $PING_SCRIPT
echo  "set xtics format \" \";" >> $PING_SCRIPT

# Set the y axis range for the 1st plot
echo -ne "set yrange [0:1870];\n" >> $PING_SCRIPT

echo -ne "plot " >> $PING_SCRIPT

# this one is in the C2S direction
#echo -ne "'< cat $WIN_ACK_TRIG_FILE' u 1:(\$$ACK_TRIG_WINDOWED_QD_C2S_COL) with linespoints axes x1y1 title 'ack_trig_windowed_qd_C2S' , " >> $PING_SCRIPT

echo -ne "'< cat $WIN_ACK_TRIG_FILE' u (\$1-$FIRST_TIME):(\$$ACK_TRIG_WINDOWED_QD_S2C_COL) with points axes x1y1 title 'qd'" >> $PING_SCRIPT

echo -ne ", '< cut -d= -f4- $PING_OUT_FILE' u (\$1-$FIRST_TIME):3 with lines axes x1y1 title 'ping rtt';\n" >> $PING_SCRIPT
echo -ne "set xrange [GPVAL_X_MIN:GPVAL_X_MAX];\n" >> $PING_SCRIPT

#### 2nd PLOT

echo -ne "set ylab 'validity ratio'; set y2lab 'samples/sec'; set ytics nomirror; set y2tics;\n" >> $PING_SCRIPT
echo -ne "set format x \"%g\";\n" >> $PING_SCRIPT
echo -ne "set xlab 'timestamp';\n" >> $PING_SCRIPT
echo -ne "set xtics nomirror rotate by -90;\n" >> $PING_SCRIPT

# Set the y axis range for the 1st plot
echo -ne "set yrange [0:1.1];\n" >> $PING_SCRIPT
echo -ne "set y2range [0:30];\n" >> $PING_SCRIPT


echo -ne "plot " >> $PING_SCRIPT

echo -ne "'< cat $WIN_ACK_TRIG_FILE' u (\$1-$FIRST_TIME):(\$$NO_QD_SAMPLES_S2C_COL) with lines axes x1y2 title 'qd_samples/sec'" >> $PING_SCRIPT

echo -ne ", \"< awk '{if(\$$CHANCES_IN_WIN_S2C_COL>0) print \$1,\$$NO_QD_SAMPLES_S2C_COL/\$$CHANCES_IN_WIN_S2C_COL }' $WIN_ACK_TRIG_FILE\" u (\$1-$FIRST_TIME):2 with points axes x1y1 title 'validity ratio' " >> $PING_SCRIPT
echo -ne ";\n" >> $PING_SCRIPT

#To be sure that the 2 graphs have exactly the same ticks
echo -ne "set xrange [GPVAL_X_MIN:GPVAL_X_MAX];\n" >> $PING_SCRIPT


# Activate the following line if you want to see plots online.
# echo -ne "pause 2; reread;\n" >> $PING_SCRIPT
