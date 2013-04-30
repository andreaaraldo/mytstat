library(plyr)

field_names=c("edge", "ipaddr1","port1","ipaddr2","port2",
              "type_C2S",
              "windowed_qd_C2S","error_C2S","max_qd_C2S",
              "chances_C2S",
              "grossdelay_C2S","conn_id_C2S","qd_samples_C2S",
              "not_void_windows_C2S","sample_qd_sum_C2S",
              "window_qd_sum_C2S",
              "sample_qd_sum_until_last_window_C2S",
              "delay_base_C2S",
              
              "type_S2C",
              "windowed_qd_S2C","error_S2C","max_qd_S2C",
              "chances_S2C",
              "grossdelay_S2C","conn_id_S2C","qd_samples_S2C",
              "not_void_windows_S2C","sample_qd_sum_S2C",
              "window_qd_sum_S2C",
              "sample_qd_sum_until_last_window_S2C",
              "delay_base_S2C")

windows = read.table("/home/araldo/analysis_outputs/14_56_21_Jun.dump01.gz/2007_06_21_14_56.out/log_tcp_windowed_qd_acktrig",
               sep=" ", 
               col.names=field_names, 
               na.strings = "-",
               fill=FALSE, 
               strip.white=TRUE)

#Take all the windows with a windowed_qd_C2S>=100ms
affected_flows_C2S_ = windows[
    windows$windowed_qd_C2S>=100 &
    windows$qd_samples_C2S>0
    ,
    c("ipaddr1","port1","ipaddr2","port2")
    ]

affected_flows_S2C_ = windows[
  windows$windowed_qd_S2C>=100 &
    windows$qd_samples_S2C>0
  ,
  c("ipaddr1","port1","ipaddr2","port2")
  ]


#Find the affected flows, i.e. the flows that have experienced 
#a qd >= 100ms and, for each of them, count how many times it
#happens
affected_flows_C2S <- ddply(affected_flows_C2S_, 
      .(ipaddr1,port1,ipaddr2,port2), summarise, 
      count_C2S=length(port2) )

affected_flows_S2C <- ddply(affected_flows_S2C_, 
      .(ipaddr1,port1,ipaddr2,port2), summarise, 
      count_S2C=length(port2) )

#Do a left outer join between windows and affected_flows
#For each window in windows_with_annotation,
#count_C2S==NA if the corrisponding flow, in C2S sense, is not 
#an affected one.
#The same holds for the S2C direction
windows_with_annotation_ <- merge(windows,affected_flows_C2S,
              all.x=TRUE)

windows_with_annotation <- merge(windows_with_annotation_,
                affected_flows_S2C, all.x=TRUE)

Da verificare che count_C2S e count_S2C non siano mai 0

# Take only the qd of the affected flows in C2S direction
qd_of_affected_flows_C2S <- 
    windows_with_annotation[
      is.na(windows_with_annotation$count_C2S),
      "windowed_qd_C2S"]

qd_of_affected_flows_S2C <- 
    windows_with_annotation[
      !is.na(windows_with_annotation$count_S2C),
      "windowed_qd_S2C"]

# Verification
# windows[windows$ipaddr1=="1.0.111.90" &
#         windows$port1==36932 &
#         windows$ipaddr2=="41.3.207.106" &
#         windows$port2==4662&
#         windows$windowed_qd_C2S>=100 &
#         windows$qd_samples_C2S>0
#         ,"edge" 
#         ]