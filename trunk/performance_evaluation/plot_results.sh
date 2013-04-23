#----------------------------------------------------------------------
#v1:
#:> /tmp/ping.DATA

RESULT_FOLDER=$1
PING_SCRIPT=~/temp/performance.plot

sh ~/tstat/performance_evaluation/build_gnuplot_script.sh $RESULT_FOLDER $PING_SCRIPT
gnuplot $PING_SCRIPT

