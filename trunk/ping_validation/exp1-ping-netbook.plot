#----------------------------------------------------------------------
#v1:
#:> /tmp/ping.DATA


TSTAT_OUT_FOLDER=/tmp/tstat_out
TSTAT_LOG=/tmp/tstat.log
TARGET=desktop
DEV=eth0
TSTAT_FOLDER=/home/andrea/tstat
LOG_FOLDER=$TSTAT_FOLDER/ping_validation/logs
OUTPUT_IMAGE=$LOG_FOLDER/plot.png
PORT_TO_SNIFF=5001
FILTER_FILE=$TSTAT_FOLDER/ping_validation/filter

killall ping
killall tstat
#killall iperf
#killall iperf
#killall iperf

rm $TSTAT_LOG
rm /tmp/ping.gp

#Initialize ping data file to avoid gnuplot errors
chmod ugoa+rwx /tmp/ping.DATA
echo "0 0 0" > /tmp/ping.DATA

ping -D $TARGET |   perl -ne 'BEGIN { $|=1 } m/^\[(\d+.?\d*).*req\=(\d+).*time\=(\d+.?\d*)\s*ms/; print "$1 $2 $3\n"; ' > /tmp/ping.DATA &

chmod ugoa+rwx /tmp/ping.DATA
echo "port $PORT_TO_SNIFF" > $FILTER_FILE
tstat  -i $DEV -l -f $FILTER_FILE -s $TSTAT_OUT_FOLDER > $TSTAT_LOG 2>&1 &

sleep 2
ITGSend -T TCP -a desktop -rp 5001 -t 1000000 &

sleep 5
#Get the latest analysis
WIN_ACK_TRIG_FILE=/tmp/tstat_out/`ls -Artl $TSTAT_OUT_FOLDER | tail -n1 | tr -s ' ' | cut -f9 -d' '`/log_tcp_windowed_qd_acktrig
WIN_DATA_TRIG_FILE=/tmp/tstat_out/`ls -Artl $TSTAT_OUT_FOLDER | tail -n1 | tr -s ' ' | cut -f9 -d' '`/log_tcp_windowed_qd_datatrig
SAMPLE_ACK_TRIG_FILE=/tmp/tstat_out/`ls -Artl $TSTAT_OUT_FOLDER | tail -n1 | tr -s ' ' | cut -f9 -d' '`/log_tcp_qd_sample_acktrig

#Setting gnuplot instructions
#see: http://hxcaine.com/blog/2013/02/28/running-gnuplot-as-a-live-graph-with-automatic-updates/

#to print both graphs
echo  "set grid; show grid; set xlab 'timestamp'; set ylab '[ms]'; set y2lab 'no samples'; set ytics nomirror; set y2tics; plot '< cat $WIN_ACK_TRIG_FILE' u 1:(\$11) with linespoints axes x1y1 title 'data2ack_C2S', '< cat $WIN_ACK_TRIG_FILE' u 1:(\$24) with linespoints axes x1y1 title 'data2ack_S2C', '< cat $WIN_ACK_TRIG_FILE' u 1:(\$7) with linespoints axes x1y1 title 'ack_trig_windowed_qd_C2S', '< cat $WIN_ACK_TRIG_FILE' u 1:(\$20) with linespoints axes x1y1 title 'ack_trig_windowed_qd_S2C', '< cat $WIN_ACK_TRIG_FILE' u 1:(\$13) with linespoints axes x1y2 title 'no samples_C2S', '< cat $WIN_ACK_TRIG_FILE' u 1:(\$26) with linespoints axes x1y2 title 'no samples_S2C', '< cut -d= -f4- /tmp/ping.DATA' u 1:3 with linespoints axes x1y1 title 'rtt_ping' ; pause 2; reread" > /tmp/ping.gp

#echo  "set grid; show grid; set xlab 'timestamp'; set ylab '[ms]'; set y2lab 'no samples'; set ytics nomirror; set y2tics; plot '< cat $WIN_ACK_TRIG_FILE' u 1:(\$11) with linespoints axes x1y1 title 'data2ack', '< cut -d= -f4- /tmp/ping.DATA' u 1:3 with linespoints axes x1y1 title 'rtt_ping' ; pause 2; reread" > /tmp/ping.gp

sleep 2
echo "launching gnuplot"
gnuplot /tmp/ping.gp
exit 
