#!/bin/bash -

if [ $# -ne 4 ]
then
	echo -ne "usage
	tstat_machine_gun <traces_folder> <left_edge> <right_edge> <output_folder>\n
	all traces starting from the <left_edge>-th to the <right_edge>-th will be
	processed
	"
	exit 1; 
fi

#Folder containing the traces
FOLDER=$1 #the traces are located here
LEFT=$2
RIGHT=$3
TSTAT_OUTPUT_FOLDER=$4


TRACE_FORMAT=pcap
TIME_RESULT_FOLDER=~/time_results

rm -r $TSTAT_OUTPUT_FOLDER/*


echo "tstat machine gun running"
echo "folder: $FOLDER"
echo "left: $LEFT"

I=1
for f in `ls $FOLDER/*.$TRACE_FORMAT`; do
	tracename=`basename $f`
	if  [ $I -ge $LEFT ] && [ $I -le $RIGHT ]  
	then
		if [ ! -d "$TSTAT_OUTPUT_FOLDER/$tracename" ]; then
			echo -ne "\n\nprocessing trace $tracename"
			mkdir $TSTAT_OUTPUT_FOLDER/$tracename
			echo "output file= $TIME_RESULT_FOLDER/$tracename.txt"
			time tstat -s $TSTAT_OUTPUT_FOLDER/$tracename > null $f
#			time --output=$TIME_RESULT_FOLDER/$tracename.txt tstat -s $TSTAT_OUTPUT_FOLDER/$tracename $f
		else
			echo "$tracename already processed"
		fi
	fi

	I=`expr $I + 1`
done
echo "end"
