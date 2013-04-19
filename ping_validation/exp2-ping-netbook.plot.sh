#----------------------------------------------------------------------
#v1:
#:> /tmp/ping.DATA


TSTAT_OUT_FOLDER=/tmp/tstat_out
TSTAT_LOG=/tmp/tstat.log
IPERF_LOG=/tmp/iperf.log
TARGET=desktop
DEV=eth0
TSTAT_FOLDER=/home/andrea/tstat
LOG_FOLDER=$TSTAT_FOLDER/ping_validation/logs
OUTPUT_IMAGE=$LOG_FOLDER/plot.png
PORT_TO_SNIFF=5011
FILTER_FILE=$TSTAT_FOLDER/ping_validation/filter
PING_SCRIPT=/tmp/ping.gp

rm $TSTAT_LOG
rm $PING_SCRIPT

#Initialize ping data file to avoid gnuplot errors
chmod ugoa+rwx /tmp/ping.DATA
echo "0 0 0" > /tmp/ping.DATA

ping -D $TARGET |   perl -ne 'BEGIN { $|=1 } m/^\[(\d+.?\d*).*req\=(\d+).*time\=(\d+.?\d*)\s*ms/; print "$1 $2 $3\n"; ' > /tmp/ping.DATA &

chmod ugoa+rwx /tmp/ping.DATA
echo "port $PORT_TO_SNIFF" > $FILTER_FILE
nohup tstat  -i $DEV -l -f $FILTER_FILE -s $TSTAT_OUT_FOLDER > $TSTAT_LOG 2>&1 &

sleep 2
iperf -t 2000000 -c desktop -s $TSTAT_OUT_FOLDER --port $PORT_TO_SNIFF> $IPERF_LOG 2>&1 &

sleep 5
sh $TSTAT_FOLDER/ping_validation/build_gnuplot_script.sh $TSTAT_OUT_FOLDER $PING_SCRIPT


sleep 2
echo "launching gnuplot"
gnuplot $PING_SCRIPT
exit
