NETBOOK_TSTAT_FOLDER=/home/andrea/tstat
DESKTOP_TSTAT_FOLDER=/home/araldo/tstat
NETBOOK_PING_SCRIPT=$NETBOOK_TSTAT_FOLDER/ping_validation/exp1-ping-netbook.plot.sh
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
ssh -n -f root@netbook "iperf -s --port "$CROSS_TRAFFIC_PORT" --interval 2 > "$NETBOOK_LOG_FOLDER"/iperfserv.log ; nohup ./whatever > /dev/null 2>&1 &"

sleep 1
echo "Receivers started"

ssh -n -f root@netbook 'sh '$NETBOOK_PING_SCRIPT"; nohup ./whatever > /dev/null 2>&1 &"
echo "netbook ping script started"

sleep 10
echo "starting cross traffic"
iperf -t 10 -c netbook --port $CROSS_TRAFFIC_PORT
echo "cross traffic ended"
