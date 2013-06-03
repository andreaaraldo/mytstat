### author: andrea.araldo@gmail.com

#----------------------------------------------------------------------
#v1:
#:> /tmp/ping.DATAGGGAF
PORT_TO_SNIFF=$1

[[ "$#" == "1"  ]] || { 
	echo "ERROR. Missing parameters. usage
	$0 <port_to_sniff>
	"
	exit 1; 
}


# All the environment variables used here, are taken from the script included 
# in the next line
MYDIR=`dirname $0`
source $MYDIR/exp2-netbook-variables_conf.sh


rm $TSTAT_LOG
rm $PING_SCRIPT

tcpdump -w $PCAP_TRACE -i $DEV \(src desktop or dst desktop\) and tcp and port $PORT_TO_SNIFF  &
TCPDUMP_PID=$!

#Initialize ping data file to avoid gnuplot errors
chmod ugoa+rwx $PING_OUT_FILE
echo "0 0 0" > $PING_OUT_FILE

ping -D $TARGET |   perl -ne 'BEGIN { $|=1 } m/^\[(\d+.?\d*).*req\=(\d+).*time\=(\d+.?\d*)\s*ms/; print "$1 $2 $3\n"; ' > $PING_OUT_FILE &
PING_PID=$!

chmod ugoa+rwx $PING_OUT_FILE
echo "port $PORT_TO_SNIFF" > $FILTER_FILE
nohup tstat  -i $DEV -l -f $FILTER_FILE -s $TSTAT_OUT_FOLDER > $TSTAT_LOG 2>&1 &
TSTAT_PID=$!

sleep 2
iperf -t 2000000 -c desktop -s $TSTAT_OUT_FOLDER --port $PORT_TO_SNIFF> $IPERF_LOG 2>&1 &
IPERF_PID=$!

sleep 5
sh $TSTAT_FOLDER/ping_validation/build_gnuplot_script.sh


sleep 2
echo "launching gnuplot"
gnuplot $PING_SCRIPT

#Killing processes
#kill -2 $TCPDUMP_PID
#kill -2 $PING_PID
#kill -2 $TSTAT_PID
#kill -2 $IPERF_PID

exit
