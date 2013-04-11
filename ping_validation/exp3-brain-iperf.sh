NETBOOK_TSTAT_FOLDER=/home/andrea/tstat
DESKTOP_TSTAT_FOLDER=/home/araldo/tstat
NETBOOK_PING_SCRIPT=$NETBOOK_TSTAT_FOLDER/ping_validation/exp2-ping-netbook.plot.sh
DESKTOP_PING_SCRIPT=$DESKTOP_TSTAT_FOLDER/ping_validation/ping.plot
NETBOOK_LOG_FOLDER=$NETBOOK_TSTAT_FOLDER/ping_validation/logs
DESKTOP_LOG_FOLDER=$DESKTOP_TSTAT_FOLDER/ping_validation/logs
CROSS_TRAFFIC_PORT=5012

#ntpdate ntp.ubuntu.com
#ssh root@netbook 'ntpdate ntp.ubuntu.com'

killall tstat; killall ping; killall iperf; killall iperf; killall iperf; killall iperf; 
ssh -n -f root@netbook "killall gnuplot; killall tstat; killall ping; killall iperf; killall iperf; killall iperf; killall iperf; nohup ./whatever > /dev/null 2>&1 &"

ethtool -s eth0 autoneg off
ethtool -s eth0 speed 10 duplex full

iperf -s --port 5011 --interval 2 > $DESKTOP_LOG_FOLDER/iperfserv.log &
ssh -n -f root@netbook "iperf -s --udp --port "$CROSS_TRAFFIC_PORT" --interval 2 > "$NETBOOK_LOG_FOLDER"/iperfserv.log ; nohup ./whatever > /dev/null 2>&1 &"

sleep 1
echo "Receivers started"

ssh -n -f root@netbook 'sh '$NETBOOK_PING_SCRIPT"; nohup ./whatever > /dev/null 2>&1 &"
echo "netbook ping script started"

sleep 15;
echo "starting cross traffic"
#50 100 500 1000 5000 10000 50000 
for bandwidth in 5M 8M 9M;
do 
	echo "iperf -t 15 --udp -c netbook --port $CROSS_TRAFFIC_PORT --bandwidth $bandwidth;"
	iperf -t 15 -c netbook --udp --port $CROSS_TRAFFIC_PORT --bandwidth $bandwidth;
	sleep 15;
done

ssh -n -f root@netbook "killall tstat; killall iperf; killall iperf; killall iperf; killall iperf; killall ping"

echo "cross traffic ended"
