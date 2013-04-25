### This script unifies the all the windowed qd log files into a single large file

if [ $# -ne 3 ]
then
	echo "usage:    $0 <log_folder> <aggregate_file_to_create> <processor>"
	exit 1; 
fi

LOG_FOLDER=$1
AGGREGATE_FILE=$2
PROCESSOR=$3

i=0
j=0
echo "" > $AGGREGATE_FILE
for trace_folder in `ls $LOG_FOLDER`; do
	if [ $i -gt 5 ] 
	then
		break;
	fi
	for subfolder in `ls $LOG_FOLDER/$trace_folder`; do
		logfile=$LOG_FOLDER/$trace_folder/$subfolder/log_tcp_windowed_qd_acktrig
		echo "processing "$logfile
		sh $PROCESSOR $logfile >> $AGGREGATE_FILE
	done
	i=`expr $i + 1`
done

echo "aggregate file created:"
ls -l $AGGREGATE_FILE

