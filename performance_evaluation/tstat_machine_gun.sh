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
OUTPUT_FOLDER=$4

rm -r $OUTPUT_FOLDER/*

TRACE_FORMAT=gz

echo "tstat machine gun running"
echo "folder: $FOLDER"
echo "left: $LEFT"

I=1
for f in `ls $FOLDER/*.$TRACE_FORMAT`; do
	tracename=`basename $f`
	if  [ $I -ge $LEFT ] && [ $I -le $RIGHT ]  
	then
		if [ ! -d "$OUTPUT_FOLDER/$tracename" ]; then
			echo "processing trace $tracename"
			mkdir $OUTPUT_FOLDER/$tracename	
			tstat -s $OUTPUT_FOLDER/$tracename $f > null
		else
			echo "$tracename already processed"
		fi
	fi

	I=`expr $I + 1`
done
echo "end"
