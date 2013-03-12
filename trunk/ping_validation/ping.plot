#----------------------------------------------------------------------
#v1:
#:> /tmp/ping.DATA
killall ping
killall tstat

#Setting gnuplot instructions
echo  "set xlab 'sample'; set ylab 'rtt [ms]'; plot '< cut -d= -f4- /tmp/ping.DATA' u 1:3 w l t '' , '< cut -d= -f4- /tmp/ping.DATA' u 1:($3-9000) w l t '' ; pause 2; reread" > /tmp/ping.gp

#Initialize ping data file to avoid gnuplot errors
echo "0 0 0" > /tmp/ping.DATA

#sudo tstat/tstat -i lo -l -s /tmp/tstat_out &

ping -D localhost |   perl -ne 'BEGIN { $|=1 } m/^\[(\d+.?\d*).*req\=(\d+).*time\=(\d+.?\d*)\s*ms/; print "$1 $2 $3\n"; ' > /tmp/ping.DATA &

sleep 2

gnuplot /tmp/ping.gp
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
