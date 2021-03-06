#!/bin/bash

## You are expected to launch this script with SEVERE_DEBUG_FLAG enabled in tstat configuration

FOLDER=$1 #the traces are located here
LEFT=$2 #starting from 1
RIGHT=$3
TSTAT_OUTPUT_FOLDER=$4
NETWORK_DESCRIPTOR_FILE=$5

TRACE_FORMAT=gz
OUTPUT_SPECIFIER="> null"
#OUTPUT_SPECIFIER="> ../temp/r_out/tstat.log 2>&1"


I=1
for f in `ls $FOLDER/*.$TRACE_FORMAT`; do
	tracename=`basename $f`
	if  [ $I -ge $LEFT ] && [ $I -le $RIGHT ]  
	then
		echo "verifying trace $I-th: $tracename"
		echo "launching tstat -N $NETWORK_DESCRIPTOR_FILE -s $TSTAT_OUTPUT_FOLDER/$tracename $f  $OUTPUT_SPECIFIER"
		tstat -N $NETWORK_DESCRIPTOR_FILE -s $TSTAT_OUTPUT_FOLDER/$tracename $f > ../temp/r_out/tstat.log 2>&1
		exit_code=$?
		echo "exit code:"$exit_code
		if [ $exit_code -ne 0 ]
		then
			echo "ERROR: exit code "$exit_code
		fi
	fi

	I=`expr $I + 1`
done
