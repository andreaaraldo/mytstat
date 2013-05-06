library(plyr)


####### CONSTANTS
percentiles_cdf_plot <- "/home/araldo/temp/percentiles_cdf.jpg"
qd_pdf_plot <- "/home/araldo/temp/qd_pdf.jpg"
percentiles_savefile <- "/home/araldo/temp/percentiles.R.save"
qd_of_flows_to_study_savefile <- 
    "/home/araldo/temp/qd_flows_to_study.R.save"
chosen_qd_threshold <- 0
chosen_flow_length_threshold <- 0


# We will consider only flows in which we observe at least flow_length_threshold
# non  empty windows and that have experienced at least one time a 
# windowed_qd >= qd_threshold
process_windows <- function(windows, qd_threshold, 
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
    
    
    ####### flows_to_study
    
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
    flows_to_study_C2S_ <- merge(suspected_windows_C2S_, long_flows_C2S)
    flows_to_study_S2C_ <- merge(suspected_windows_S2C_, long_flows_S2C)
    
    #Purge duplicated flows
    flows_to_study_C2S <- 
        flows_to_study_C2S_[ 
            !duplicated( flows_to_study_C2S_[,flow_id_vector]), 
            ]
    
    flows_to_study_S2C <- 
        flows_to_study_S2C_[ 
            !duplicated( flows_to_study_S2C_[,flow_id_vector]), 
            ]
    
    
    ####### Ratios
    affected_ratio_over_all_flows <- 
        ( length(flows_to_study_C2S[,1]) + 
              length(flows_to_study_S2C[,1]) ) /
        ( length(all_non_empty_flows_C2S[,1]) + 
              length(all_non_empty_flows_S2C[,1]) 
        )
    
    affected_ratio_over_long_enough_flows <- 
        (   length(flows_to_study_C2S[,1]) + 
                length(flows_to_study_S2C[,1]) ) /
        (   length(long_flows_C2S[,1]) + 
                length(long_flows_S2C[,1]) 
        )
    
    length(flows_to_study_C2S[,1])
    length(flows_to_study_S2C[,1])
    length(long_flows_C2S[,1])
    length(long_flows_S2C[,1])
    length(all_non_empty_flows_C2S[,1])
    length(all_non_empty_flows_S2C[,1])
    ####### windowed qd of the affected flows
    
    # Take the windows of the affected flows
    windows_to_study_C2S_ <- merge(windows, flows_to_study_C2S)
    windows_to_study_S2C_ <- merge(windows, flows_to_study_S2C)
    
    # Consider only the non empty windows
    windows_to_study_C2S <- 
        windows_to_study_C2S_[
            windows_to_study_C2S_$qd_samples_C2S>0,]
    
    windows_to_study_S2C <- 
        windows_to_study_S2C_[
            windows_to_study_S2C_$qd_samples_S2C>0,]
    
    qd_of_flows_to_study_C2S <- 
        windows_to_study_C2S[, "windowed_qd_C2S"]
    
    qd_of_flows_to_study_S2C <- 
        windows_to_study_S2C[, "windowed_qd_S2C"]
    
    # Unify C2S and S2C directions
    qd_of_flows_to_study <-
        c(qd_of_flows_to_study_C2S, qd_of_flows_to_study_S2C)
    
    ####### Per flow percentiles
    percentiles_df_C2S <- 
        ddply(windows_to_study_C2S, .(ipaddr1, port1, ipaddr2, port2), 
              summarize, 
              percentile_90 = quantile( windowed_qd_C2S, c(.90)),
              percentile_95 = quantile( windowed_qd_C2S, c(.95)),
              percentile_99 = quantile( windowed_qd_C2S, c(.99))
        )
    
    percentiles_df_S2C <- 
        ddply(windows_to_study_S2C, .(ipaddr1, port1, ipaddr2, port2), 
              summarize, 
              percentile_90 = quantile( windowed_qd_S2C, c(.90)), 
              percentile_95 = quantile( windowed_qd_S2C, c(.95)), 
              percentile_99 = quantile( windowed_qd_S2C, c(.99))
        )

    
    # Unify percentiles
    percentile_names <- c("percentile_90","percentile_95","percentile_99")
    percentiles <- rbind( percentiles_df_C2S[,percentile_names],
                          percentiles_df_S2C[,percentile_names])
    
    
    #######SEVERE_DEBUG: begin
    
    # For we have taken only the windows with qd_samples>0, in all windows
    # should be possible to compute the windowed qd. Therefore, NA value
    # are impossibile
    if( length( qd_of_flows_to_study[is.na(qd_of_flows_to_study)]) != 0)
        stop("ERROR: NA value are forbidden in qd_of_flows_to_study")
    
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
    
    # Sarebbe bello printarli
    qd_threshold
    flow_length_threshold
    affected_ratio_over_all_flows
    affected_ratio_over_long_enough_flows
    length(qd_of_flows_to_study)
    quantile(qd_of_flows_to_study,c(.90,.95,.99))
    
    return(list(qd_of_flows_to_study=qd_of_flows_to_study, 
                percentiles=percentiles) )
}

plot_percentiles <- function(percentiles)
{
    max_x <- max(c(max(percentiles[,c("percentile_90")]),
                   max(percentiles[,c("percentile_95")]),
                   max(percentiles[,c("percentile_99")]) )
    )
    jpeg(percentiles_cdf_plot)
    
    plot(ecdf(percentiles[,c("percentile_90")]), 
         log="x", xlim=c(1,max_x))
    
    plot(ecdf(percentiles[,c("percentile_95")]), 
         log="x", xlim=c(1,max_x), add=TRUE )
    
    plot(ecdf(percentiles[,c("percentile_99")]), 
         log="x", xlim=c(1,max_x), add=TRUE )
    
    dev.off()
}

plot_qd <- function(qd_of_flows_to_study)
{
    jpeg(qd_pdf_plot)
    bins <- seq(min(qd_of_flows_to_study), 
                max(qd_of_flows_to_study)+10,10)
    
    zoom <- c(0,1000)
    hist(qd_of_flows_to_study, breaks=bins, xlim=zoom, 
             plot=TRUE)
    dev.off()
}

load_window_log <- function(filename)
{
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
    
    windows <- read.table(filename,
                           sep=" ", 
                           col.names=field_names, 
                           na.strings = "-",
                           fill=FALSE, 
                           strip.white=TRUE)

    return(windows)
}

process_logfile <- function(filename)
{
    windows_ <-load_window_log(filename)
    
    result <- process_windows(
        windows=windows_[,], 
        qd_threshold=chosen_qd_threshold, 
        flow_length_threshold=flow_length_threshold)

    return(result)
}

filelist <- list.files(path = "/home/araldo/analysis_outputs/", 
           pattern = "*log_tcp_windowed_qd_acktrig", all.files = FALSE,
           full.names = TRUE, recursive = TRUE,
           ignore.case = FALSE, include.dirs = FALSE)

result <- process_logfile(filelist[1])
percentiles <- result$percentiles
qd_of_flows_to_study <- result$qd_of_flows_to_study

for (filename in filelist[2:length(filelist)])
{
    print("Processing another file")
    result <- process_logfile(filename)
    percentiles <- rbind(percentiles, result$percentiles)
    
    qd_of_flows_to_study <- 
        c(qd_of_flows_to_study, result$qd_of_flows_to_study)
}

save(percentiles, file=percentiles_savefile)
save(qd_of_flows_to_study, file=qd_of_flows_to_study_savefile)


load(percentiles_savefile)
plot_percentiles(percentiles)
load(qd_of_flows_to_study_savefile)
plot_qd(qd_of_flows_to_study)