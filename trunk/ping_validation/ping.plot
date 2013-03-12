#----------------------------------------------------------------------
#v1:
:> /tmp/ping.DATA
killall ping

ping -D localhost |   perl -ne 'BEGIN { $|=1 } m/^\[(\d+.?\d*).*req\=(\d+).*time\=(\d+.?\d*)\s*ms/; print "$1 $2 $3\n"; ' > /tmp/ping.DATA &


sleep 2

echo  "set xlab 'sample'; set ylab 'rtt [ms]'; plot '< cut -d= -f4- /tmp/ping.DATA' u 2:3 w l t ''; pause 1; reread" > /tmp/ping.gp

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
