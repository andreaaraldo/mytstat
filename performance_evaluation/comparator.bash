#!/bin/bash

TSTAT_PATH=~/tstat
TRACE_FOLDER=~/fastweb2
LEFT=1
RIGHT=59

$TSTAT_PATH/performance_evaluation/config_tester.bash $TRACE_FOLDER  $LEFT $RIGHT  ~/analysis_outputs $TSTAT_PATH/performance_evaluation/tstat_configs/Makefile.conf.1
$TSTAT_PATH/performance_evaluation/config_tester.bash $TRACE_FOLDER  $LEFT $RIGHT  ~/analysis_outputs $TSTAT_PATH/performance_evaluation/tstat_configs/Makefile.conf.2
$TSTAT_PATH/performance_evaluation/config_tester.bash $TRACE_FOLDER  $LEFT $RIGHT  ~/analysis_outputs $TSTAT_PATH/performance_evaluation/tstat_configs/Makefile.conf.3
$TSTAT_PATH/performance_evaluation/config_tester.bash $TRACE_FOLDER  $LEFT $RIGHT  ~/analysis_outputs $TSTAT_PATH/performance_evaluation/tstat_configs/Makefile.conf.4

