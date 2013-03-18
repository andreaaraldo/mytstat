#----------------------------------------------------------------------
#v1:
#:> /tmp/ping.DATA

killall ping

TSTAT_OUT_FOLDER=/tmp/tstat_out

#sudo tstat -i lo -l -s /tmp/tstat_out &

#Get the latest analysis
TSTAT_OUT_FILE=/tmp/tstat_out/`ls -Artl $TSTAT_OUT_FOLDER | tail -n1 | cut -f9 -d' '`/log_tcp_windowed_qd_acktrig

echo "tstat output file is $TSTAT_OUT_FILE"

#Setting gnuplot instructions
#see: http://hxcaine.com/blog/2013/02/28/running-gnuplot-as-a-live-graph-with-automatic-updates/

#to print ping only
#echo  "set xlab 'sample'; set ylab '[ms]'; plot '< cut -d= -f4- /tmp/ping.DATA' u 1:3 with lines title 'rtt'; pause 2; reread" > /tmp/ping.gp

#to print both graphs
#echo  "set xlab 'sample'; set ylab '[ms]'; plot '< cut -d= -f4- /tmp/ping.DATA' u 1:3 with lines title 'rtt', '$TSTAT_OUT_FILE' u 1:(\$7+\$20) with lines title 'qd' ; pause 2; reread" > /tmp/ping.gp

#to print tstat graph only
echo  "set xlab 'sample'; set ylab '[ms]'; plot '< cat $TSTAT_OUT_FILE' u 1:(\$7) with lines title 'qd' ; pause 2; reread" > /tmp/ping.gp

#Initialize ping data file to avoid gnuplot errors
echo "0 0 0" > /tmp/ping.DATA


#ping -D localhost |   perl -ne 'BEGIN { $|=1 } m/^\[(\d+.?\d*).*req\=(\d+).*time\=(\d+.?\d*)\s*ms/; print "$1 $2 $3\n"; ' > /tmp/ping.DATA &

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
