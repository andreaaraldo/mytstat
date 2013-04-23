#!/bin/bash

### DO NOT INVOKE THIS SCRIPT WITH sh <scriptname>. INSTEAD INVOKE ./<scriptname>
### This is related to the time issue described here:
### 	http://unix.stackexchange.com/questions/27920/why-bash-time-is-more-precise-then-gnu-time

# This script will test a configuration. The configuration must be described in the file whose name is
# CONFIG_TO_TEST; This file must be in the same format of tstat/Makefile.conf.


if [ $# -ne 5 ]
then
	echo -ne "usage
	tstat_machine_gun <traces_folder> <left_edge> <right_edge> <output_folder> <Makefile.conf>\n
	all traces starting from the <left_edge>-th to the <right_edge>-th will be processed with 
	tstat configured as defined in <Makefile.conf>
	"
	exit 1; 
fi

#Folder containing the traces
FOLDER=$1 #the traces are located here
LEFT=$2
RIGHT=$3
TSTAT_OUTPUT_FOLDER=$4
CONFIG_TO_TEST=$5


TRACE_FORMAT=gz
RESULT_FOLDER=~/time_results
TEMP_FILE=~/temp.txt
TSTAT_PATH=~/tstat
MAKEFILE_CONF_STANDARD_PATH=$TSTAT_PATH/tstat/Makefile.conf
CONFIG_NAME=`basename $CONFIG_TO_TEST`
RESULT_FILE=$RESULT_FOLDER/$CONFIG_NAME.results.txt

#set the tstat configuration
echo "Setting configuration $CONFIG_NAME"
cp $CONFIG_TO_TEST $MAKEFILE_CONF_STANDARD_PATH
cd $TSTAT_PATH
make distclean; sh autogen.sh; ./configure; make -j
cd -

rm -r $TSTAT_OUTPUT_FOLDER/*
rm $RESULT_FILE


echo "tstat machine gun running"
echo "folder: $FOLDER"
echo "left: $LEFT"
echo "results in $RESULT_FILE"


TIMEFORMAT='%3R'


I=1
for f in `ls $FOLDER/*.$TRACE_FORMAT`; do
	tracename=`basename $f`
	if  [ $I -ge $LEFT ] && [ $I -le $RIGHT ]  
	then
		if [ ! -d "$TSTAT_OUTPUT_FOLDER/$tracename" ]; then
			rm $TEMP_FILE
			echo -ne "\n\n\n\nprocessing trace $I-th: $tracename"
			mkdir $TSTAT_OUTPUT_FOLDER/$tracename
			echo "$tracename" >> $TEMP_FILE

			#Get the time required to run
			#the trick to print the time output is inspired by:
			#http://hustoknow.blogspot.fr/2011/08/how-to-redirect-bash-time-outputs.html

			(time tstat -s $TSTAT_OUTPUT_FOLDER/$tracename $f > null 2>&1) 2>> $TEMP_FILE
			
			#Compute the space required in the disk
			echo -ne `du --bytes --total $TSTAT_OUTPUT_FOLDER/$tracename | cut -f1 | tail -n1` >> $TEMP_FILE
			#the \t character will be printed by calc

			#Get the subdirectory name
			SUBDIR_NAME=`ls $TSTAT_OUTPUT_FOLDER/$tracename`

			#Compute the tcp flow number
			LOG_TCP_COMPLETE=$TSTAT_OUTPUT_FOLDER/$tracename/$SUBDIR_NAME/log_tcp_complete
			LOG_TCP_NOCOMPLETE=$TSTAT_OUTPUT_FOLDER/$tracename/$SUBDIR_NAME/log_tcp_nocomplete
			NO_OF_COMPLETE_FLOWS=`cat $LOG_TCP_COMPLETE | wc -l`
			NO_OF_NOCOMPLETE_FLOWS=`cat $LOG_TCP_NOCOMPLETE | wc -l`
			calc $NO_OF_COMPLETE_FLOWS+$NO_OF_NOCOMPLETE_FLOWS >> $TEMP_FILE

			#Write to the result file
			(cat $TEMP_FILE |tr "\n" "\t") >> $RESULT_FILE
			echo "" >> $RESULT_FILE
		else
			echo "$tracename already processed"
		fi
	fi

	I=`expr $I + 1`
done

: <<'END'
echo "\n\n\n############ CHECK FOR ERRORS IN PROCESSING #######"
I=1
for f in `ls $FOLDER/*.$TRACE_FORMAT`; do
	tracename=`basename $f`
	if  [ $I -ge $LEFT ] && [ $I -le $RIGHT ]  
	then
		echo "verifying trace $I-th: $tracename"
		echo "launching tstat -s $TSTAT_OUTPUT_FOLDER/$tracename $f"
		tstat -s $TSTAT_OUTPUT_FOLDER/$tracename $f
		# > null  2>&1
		exit_code=$?
		echo "exit code:"$exit_code
		if [ $exit_code -ne 0 ]
		then
			echo "ERROR: exit code "$exit_code
		fi
	fi

	I=`expr $I + 1`
done
END


echo -e "\n\nend\n"
