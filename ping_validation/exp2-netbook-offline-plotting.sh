### author: andrea.araldo@gmail.com

PORT_TO_SNIFF=$1

# All the other environment variables used here, are taken from the script included 
# in the next line
MYDIR=`dirname $0`
source $MYDIR/exp2-netbook-variables_conf.sh


OUTPUT_SPECIFIER="" #" > $TSTAT_LOG 2>&1"

[[ "$#" == "1"  ]] || { 
	echo "ERROR. Missing parameters. usage
	$0 <port_to_sniff>
	"
	exit 1; 
}



killall gnuplot

echo "port $PORT_TO_SNIFF" > $FILTER_FILE
rm -rf $TSTAT_OUT_FOLDER.old
mv -f $TSTAT_OUT_FOLDER $TSTAT_OUT_FOLDER.old
mkdir $TSTAT_OUT_FOLDER


TSTAT_COMMAND="nohup tstat -f $FILTER_FILE -s $TSTAT_OUT_FOLDER $PCAP_TRACE $OUTPUT_SPECIFIER"
echo $TSTAT_COMMAND
$TSTAT_COMMAND
mv -f nohup.out $TSTAT_LOG

EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]
then
	echo "ERROR in launching tstat: exit code "$EXIT_CODE
else
	sh $TSTAT_FOLDER/ping_validation/build_gnuplot_script.sh
	gnuplot $PING_SCRIPT	
fi

exit
