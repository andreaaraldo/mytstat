library(plyr)



# We will consider only flows in which we observe at least flow_length_threshold
# non  empty windows and that have experienced at least one time a 
# windowed_qd >= qd_threshold
process_windows <- function(dataframe, qd_threshold, 
                            flow_length_threshold)
{
    flow_id_vector <- c("ipaddr1","port1","ipaddr2","port2")
    
    
    ####### all_non_empty_flows building
    # Take all the non empty windows and project the resulting
    # dataframe on the columns that characterize a flow
    all_non_empty_flows_C2S_ <-windows[ windows$qd_samples_C2S>0,
                                        flow_id_vector ]
    
    all_non_empty_flows_S2C_ <-windows[ windows$qd_samples_S2C>0,
                                        flow_id_vector  ]
    
    # Find the flows with at least 1 non empty window. For each of them
    # calculate how many non empty windows are observed
    all_non_empty_flows_C2S <- 
        ddply(all_non_empty_flows_C2S_, .(ipaddr1,port1,ipaddr2,port2), 
              summarise, non_empty_wins_count_C2S=length(port2) 
        )
    
    all_non_empty_flows_S2C <- 
        ddply(all_non_empty_flows_S2C_, .(ipaddr1,port1,ipaddr2,port2), 
              summarise, non_empty_wins_count_S2C=length(port2) 
        )
    
    ####### Consider only the flows that are long enough
    long_flows_C2S <- all_non_empty_flows_C2S[
        all_non_empty_flows_C2S$non_empty_wins_count_C2S >= 
            flow_length_threshold,
        ]
    
    long_flows_S2C <- all_non_empty_flows_S2C[
        all_non_empty_flows_S2C$non_empty_wins_count_S2C >= 
            flow_length_threshold,
        ]
    
    
    ####### affected_flows
    
    # Take all the windows with a windowed_qd_C2S >= qd_threshold
    suspected_windows_C2S_ <- windows[
        windows$windowed_qd_C2S >= qd_threshold &
            windows$qd_samples_C2S > 0
        ,
        flow_id_vector
        ]
    
    suspected_windows_S2C_ <- windows[
        windows$windowed_qd_S2C>=qd_threshold &
            windows$qd_samples_S2C>0
        ,
        flow_id_vector
        ]
    
    # Among the windows calculated above,
    # consider only the windows of the long-enough flows. In other words,
    # ignore all the windows of too short flows.
    # The following is like an SQL inner join (from the table on the left
    # I want to preserve only the rows that have a corrispondence with 
    # some rows of the table on the right)
    affected_flows_C2S_ <- merge(suspected_windows_C2S_, long_flows_C2S)
    affected_flows_S2C_ <- merge(suspected_windows_S2C_, long_flows_S2C)
    
    #Purge duplicated flows
    affected_flows_C2S <- 
        affected_flows_C2S_[ 
            !duplicated( affected_flows_C2S_[,flow_id_vector]), 
            ]
    
    affected_flows_S2C <- 
        affected_flows_S2C_[ 
            !duplicated( affected_flows_S2C_[,flow_id_vector]), 
            ]
    
    
    ####### Ratios
    affected_ratio_over_all_flows <- 
        ( length(affected_flows_C2S[,1]) + 
              length(affected_flows_S2C[,1]) ) /
        ( length(all_non_empty_flows_C2S[,1]) + 
              length(all_non_empty_flows_S2C[,1]) 
        )
    
    affected_ratio_over_long_enough_flows <- 
        (   length(affected_flows_C2S[,1]) + 
                length(affected_flows_S2C[,1]) ) /
        (   length(long_flows_C2S[,1]) + 
                length(long_flows_S2C[,1]) 
        )
    
    length(affected_flows_C2S[,1])
    length(affected_flows_S2C[,1])
    length(long_flows_C2S[,1])
    length(long_flows_S2C[,1])
    length(all_non_empty_flows_C2S[,1])
    length(all_non_empty_flows_S2C[,1])
    ####### windowed qd of the affected flows
    
    # Take the windows of the affected flows
    qd_of_affected_flows_C2S_ <- merge(windows, affected_flows_C2S)
    qd_of_affected_flows_S2C_ <- merge(windows, affected_flows_S2C)
    
    # Consider only the non empty windows
    qd_of_affected_flows_C2S <- 
        qd_of_affected_flows_C2S_[ 
            qd_of_affected_flows_C2S_$qd_samples_C2S>0, "windowed_qd_C2S"
            ]
    
    qd_of_affected_flows_S2C <- 
        qd_of_affected_flows_S2C_[ 
            qd_of_affected_flows_S2C_$qd_samples_S2C>0, "windowed_qd_S2C"
            ]
    
    # Unify C2S and S2C directions
    qd_of_affected_flows <-
        c(qd_of_affected_flows_C2S, qd_of_affected_flows_S2C)
    
    
    #######SEVERE_DEBUG: begin
    
    # For we have taken only the windows with qd_samples>0, in all windows
    # should be possible to compute the windowed qd. Therefore, NA value
    # are impossibile
    if( length( qd_of_affected_flows[is.na(qd_of_affected_flows)]) != 0)
        stop("ERROR: NA value are forbidden in qd_of_affected_flows")
    
    if(
        length (
            long_flows_C2S[duplicated(long_flows_C2S[, flow_id_vector ] ) ] 
        ) != 0     
        |
            length (
                long_flows_S2C[duplicated(long_flows_S2C[, flow_id_vector ] ) ] 
            ) != 0 
    )
        stop("ERROR: duplicates in long_flows")
    
    #SEVERE_DEBUG: end
    
    
    print(qd_threshold)
    print(flow_length_threshold)
    print(affected_ratio_over_all_flows)
    print(affected_ratio_over_long_enough_flows)
    print(length(qd_of_affected_flows) )
    print(quantile(qd_of_affected_flows,c(.90,.95,.99)) )
    
    bins <- seq(min(qd_of_affected_flows), 
                max(qd_of_affected_flows)+10,10)
    
    zoom <- c(0,1000)
    hist(qd_of_affected_flows, breaks=bins, xlim=zoom, 
         plot=TRUE)
    
    stop("questa e' prova")
}

field_names<-c("edge", "ipaddr1","port1","ipaddr2","port2",
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

windows <- read.table("/home/araldo/analysis_outputs/14_56_21_Jun.dump01.gz/2007_06_21_14_56.out/log_tcp_windowed_qd_acktrig",
                      sep=" ", 
                      col.names=field_names, 
                      na.strings = "-",
                      fill=FALSE, 
                      strip.white=TRUE)


process_windows(windows, 0, 0)