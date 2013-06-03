NETBOOK_TSTAT_FOLDER=/home/andrea/tstat
DESKTOP_TSTAT_FOLDER=/home/araldo/tstat
NETBOOK_PING_SCRIPT=$NETBOOK_TSTAT_FOLDER/ping_validation/exp2-ping-netbook.plot.sh
DESKTOP_PING_SCRIPT=$DESKTOP_TSTAT_FOLDER/ping_validation/ping.plot
NETBOOK_LOG_FOLDER=~/temp/ping_logs
DESKTOP_LOG_FOLDER=~/temp/ping_logs
CROSS_TRAFFIC_PORT=5012
SNIFFED_TRAFFIC_PORT=5011
NETBOOK_IP=`ping -c 1 netbook | head -n 1 | cut -d"(" -f2 | cut -d")" -f1`
DESKTOP_IP=`sudo ssh -n -f root@netbook ping -c 1 desktop | head -n 1 | cut -d"(" -f2 | cut -d")" -f1`

# netem bottleneck param
UPLINK_CAPACITY=1000 #link capacity to emulate (in kbit)
LOSS_PROBABILITY=0 #(percentage)
DATARATE=7000  #we want that the netbook sends data packet in the sniffed flow
		# according to this (in kbit)

echo ""
echo ""
echo "####### Cleaning up"
killall tstat; killall ping; killall iperf; killall iperf; killall iperf; killall iperf; 
ssh -n -f root@netbook "killall tstat; killall gnuplot; killall ping; killall iperf; killall iperf; killall iperf; killall iperf;"
sleep 2

echo ""
echo ""
echo "####### Synchronizing the 2 clocks"
ntpdate ntp.ubuntu.com
ssh root@netbook 'ntpdate ntp.ubuntu.com'

echo ""
echo ""
echo "####### Setting the bottlenecks"
ethtool -s eth0 autoneg off
ethtool -s eth0 speed 10 duplex full
NETEM_COMMAND="$DESKTOP_TSTAT_FOLDER/ping_validation/network_emulation.sh $UPLINK_CAPACITY $LOSS_PROBABILITY fifo eth0 $NETBOOK_IP"
echo $NETEM_COMMAND
$NETEM_COMMAND

#I want to limit the data rate of the sniffed flow
NETEM_COMMAND_NETBOOK_SIDE="$NETBOOK_TSTAT_FOLDER/ping_validation/network_emulation.sh $DATARATE $LOSS_PROBABILITY fifo eth0 $DESKTOP_IP"
echo "on netbook: "$NETEM_COMMAND_NETBOOK_SIDE
ssh -n -f root@netbook $NETEM_COMMAND_NETBOOK_SIDE



echo ""
echo ""
echo "####### Launching the iperf servers"
iperf -s --port 5011 --interval 2 > $DESKTOP_LOG_FOLDER/iperfserv.log &
ssh -n -f root@netbook "iperf -s --port "$CROSS_TRAFFIC_PORT" --interval 2 > "$NETBOOK_LOG_FOLDER"/iperfserv.log ; nohup ./whatever > /dev/null 2>&1 &"
sleep 1
echo "Receivers started"


echo ""
echo ""
echo "####### Launching netbook ping script"
ssh -n -f root@netbook 'sh '$NETBOOK_PING_SCRIPT $SNIFFED_TRAFFIC_PORT "; nohup ./whatever > /dev/null 2>&1 &"
echo "netbook ping script started"
sleep 15;

echo ""
echo ""
echo "####### Injecting cross traffic"
#50 100 500 1000 5000 10000 50000 
for bandwidth in 1 2 3 4 5;
do 
	echo "iperf -t 5 --udp -c netbook --port $CROSS_TRAFFIC_PORT"
	iperf -t 15 -c netbook --port $CROSS_TRAFFIC_PORT;
	sleep 15;
done

echo ""
echo ""
echo "####### Cleaning up"
ssh -n -f root@netbook "killall iperf; killall iperf; killall iperf; killall iperf; killall ping; killall ping; killall ping; killall ping"
killall iperf; killall iperf
ssh -n -f root@netbook "killall -2 tstat; killall -2 tcpdump"

echo "cross traffic ended"
