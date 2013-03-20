#----------------------------------------------------------------------
#v1:
#:> /tmp/ping.DATA


TSTAT_OUT_FOLDER=/tmp/tstat_out
TSTAT_LOG=/tmp/tstat.log
TARGET=137.194.22.52
DEV=eth0

killall ping
killall tstat
killall iperf
killall iperf
killall iperf

#Initialize ping data file to avoid gnuplot errors
echo "0 0 0" > /tmp/ping.DATA

#make netem
sleep 1

ping -D $TARGET |   perl -ne 'BEGIN { $|=1 } m/^\[(\d+.?\d*).*req\=(\d+).*time\=(\d+.?\d*)\s*ms/; print "$1 $2 $3\n"; ' > /tmp/ping.DATA &
tstat  -i $DEV -l -f filter -s $TSTAT_OUT_FOLDER > $TSTAT_LOG 2>&1 &

#make srv &
sleep 1
make cli &

sleep 5
#Get the latest analysis
WIN_ACK_TRIG_FILE=/tmp/tstat_out/`ls -Artl $TSTAT_OUT_FOLDER | tail -n1 | cut -f9 -d' '`/log_tcp_windowed_qd_acktrig
WIN_DATA_TRIG_FILE=/tmp/tstat_out/`ls -Artl $TSTAT_OUT_FOLDER | tail -n1 | cut -f9 -d' '`/log_tcp_windowed_qd_datatrig
SAMPLE_ACK_TRIG_FILE=/tmp/tstat_out/`ls -Artl $TSTAT_OUT_FOLDER | tail -n1 | cut -f9 -d' '`/log_tcp_qd_sample_acktrig

echo "window ack triggered file is $WIN_ACK_TRIG_FILE"
echo "window data triggered file is $WIN_DATA_TRIG_FILE"
echo "sample ack triggered file is $SAMPLE_ACK_TRIG_FILE"

#Setting gnuplot instructions
#see: http://hxcaine.com/blog/2013/02/28/running-gnuplot-as-a-live-graph-with-automatic-updates/

#to print ping only
#echo  "set xlab 'sample'; set ylab '[ms]'; plot '< cut -d= -f4- /tmp/ping.DATA' u 1:3 with lines title 'rtt'; pause 2; reread" > /tmp/ping.gp

#to print both graphs
echo  "set grid; show grid; set xlab 'timestamp'; set ylab '[ms]'; set y2lab 'no samples'; set ytics nomirror; set y2tics; plot '< cut -d= -f4- /tmp/ping.DATA' u 1:3 with linespoints axes x1y1 title 'rtt_ping', '< cat $WIN_ACK_TRIG_FILE' u 1:(\$11) with linespoints axes x1y1 title 'data2ack', '< cat $WIN_ACK_TRIG_FILE' u 1:(\$7) with linespoints axes x1y1 title 'ack_trig_windowed_qd', '< cat $WIN_ACK_TRIG_FILE' u 1:(\$13) with linespoints axes x1y2 title 'no samples' ; pause 2; reread" > /tmp/ping.gp

#echo  "set grid; show grid; set xlab 'timestamp'; set ylab '[ms]'; plot '< cat $SAMPLE_ACK_TRIG_FILE' u 1:(\$12) with lines axes x1y1 title 'data2ack_samples' ; pause 2; reread" > /tmp/ping.gp

#to print tstat graph only
#echo  "set xlab 'sample'; set ylab '[ms]'; plot '< cat $WIN_ACK_TRIG_FILE' u 1:(\$11) with lines title 'qd' ; pause 2; reread" > /tmp/ping.gp

sleep 2
gnuplot /tmp/ping.gp
killall ping
exit 

#----------------------------------------------------------------------
#v0:
# 
# ping localhost  > /tmp/ping.DATA &
# 
# sleep 3
# 
# echo  "set xlab 'sample'; set ylab 'rtt [ms]'; plot '< cut -d= -f4- /tmp/ping.DATA' u 0:1 w l t ''; pause 1; reread" > /tmp/ping.gp
# 
# gnuplot /tmp/ping.gp
