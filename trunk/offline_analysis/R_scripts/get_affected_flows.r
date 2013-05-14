sink("~/temp/R.log")
library(plyr)


####### CONSTANTS
log_file_folder <- "/home/araldo/analysis_outputs"
percentiles_cdf_plot <- "/home/araldo/temp/percentiles_cdf.jpg"
qd_pdf_plot <- "/home/araldo/temp/qd_pdf.jpg"
proto_scatterplot_file <- "~/temp/scatter.png"
percentiles_savefile <- "/home/araldo/temp/percentiles.R.save"
point_savefile <- "/home/araldo/temp/point.R.save"
qd_of_flows_to_study_savefile <- 
    "/home/araldo/temp/qd_flows_to_study.R.save"
chosen_qd_threshold <- 0
chosen_flow_length_threshold <- 0

handle_error <- function(error_message)
{
    print("ERROR")
    print(error_message)
    stop(error_message)
}

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
        handle_error("ERROR: NA value are forbidden in qd_of_flows_to_study")
    
    if(
        length (
            long_flows_C2S[duplicated(long_flows_C2S[, flow_id_vector ] ) ] 
        ) != 0     
        |
            length (
                long_flows_S2C[duplicated(long_flows_S2C[, flow_id_vector ] ) ] 
            ) != 0 
    )
        handle_error("ERROR: duplicates in long_flows")
    
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
        flow_length_threshold=chosen_flow_length_threshold)
    
    return(result)
}

calculate_global_stats <- function(filelist)
{
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
}

get_global_stats <- function()
{
    load(percentiles_savefile)
    plot_percentiles(percentiles)
    load(qd_of_flows_to_study_savefile)
    plot_qd(qd_of_flows_to_study)
    print(quantile(qd_of_flows_to_study,c(.90,.95,.99)))
}

get_host_proto_association <- function(windows)
{
    ####### SEVERE DEBUG: begin
    if ( length(windows[windows$type_C2S != windows$type_S2C,1]) 
         != 0)
        handle_error("protocols must be the same in both directions")
    ####### SEVERE DEBUG: end
    
    protocol_column <- 
        sapply(strsplit(as.character(windows$type_C2S),":"), "[[", 1)
    
    windows$protocol_column <- protocol_column
    
    host_proto_association_A <- windows[,c("ipaddr1", "protocol_column")]
    colnames(host_proto_association_A) <- c("ipaddr", "protocol_column")
    host_proto_association_B <- windows[,c("ipaddr2", "protocol_column")]
    colnames(host_proto_association_B) <- c("ipaddr", "protocol_column")
    host_proto_association_ <- rbind(host_proto_association_A, host_proto_association_B)
    
    # Purge the duplicates
    host_proto_association <- 
        host_proto_association_[!duplicated(host_proto_association_[,]),]
    
    return(host_proto_association)
}

get_point <- function(windows)
{
    #Useful constants
    point_colnames <- 
        c("edge", "ipaddr1","port1","ipaddr2","port2",
          "windowed_qd","protocol")
    
    proto_name <- as.character( c(
    "UNKNOWN", "HTTP", "RTSP", "RTP", "ICY", "RTCP", "MSN", "YMSG",
    "XMPP", "P2P", "SKYPE", "SMTP", "POP3", "IMAP", "SSL", "OBF",
    "SSH", "RTMP", "MSE"
    ) )
    
    protocol <- c(
        0, 1, 2, 4, 8, 16, 32, 64,
        128, 256, 512, 1024, 2048, 4096, 8192, 16384,
        32768, 65536, 131072
    )
    
    proto_id <- c(
        0, 1, 2, 3, 4, 5, 6, 7,
        8, 9, 10, 11, 12, 13, 14, 15,
        16, 17, 18
    )
    
    protocol_df <- data.frame(protocol, proto_name, proto_id)
    
    host_proto_association <- get_host_proto_association(windows)
    
    ####### Find all the protocols that affect each window
    # Definition: an host H is affected by a protocol P, if there exists
    #   a flow F*, in which H is involved, that carries P
    # Definition: a flow F is affected by a protocol P, if at least one of the two
    #   hosts involved in F is affected by P
    # Definition: a window W is affected by a protocol, if it is part
    #   of a flow F affected by that protocol
    # Goal: we want to build a dataframe point, in which every window is
    #   represented by a set of rows, being each row representative of one
    #   of the protocol that affect that window W
    
    # Taking a single windowed_qd, in windows_temp1 there will be a row
    # for each protocol that affects ipaddr1.
    # Note: a single windowed_qd could lead to many rows in 
    #       windows_temp1.
    colnames(host_proto_association) <- c("ipaddr1","protocol1")
    windows_temp1 <- merge(windows, host_proto_association, all.x=TRUE)
    
    # The same as above. Here, ipaddr2 is used
    colnames(host_proto_association) <- c("ipaddr2","protocol2")
    protocol_annotated_windows <- 
        merge(windows_temp1, host_proto_association, all.x=TRUE)
    
    # Now, for each window, we want a set of rows such that the set of protocols
    # that they represent is the union between the protocols that affect ipaddr1
    # and the protocols that affect ipaddr2
    
    # For each window in C2S dir, find the protocols that affect
    # ipaddr1
    point_C2S_1 <- 
        protocol_annotated_windows[
            protocol_annotated_windows$qd_samples_C2S>0,
            c("edge", "ipaddr1","port1","ipaddr2","port2",
              "windowed_qd_C2S","protocol1")]
    
    # For each window in C2S dir, find the protocols that affect
    # ipaddr2
    point_C2S_2 <- 
        protocol_annotated_windows[
            protocol_annotated_windows$qd_samples_C2S>0,
            c("edge", "ipaddr1","port1","ipaddr2","port2",
              "windowed_qd_C2S","protocol2")]
    
    # For each window in C2S, unify the protocols that affect ipaddr1
    # and the protocols that affect ipaddr2
    colnames(point_C2S_1) <- point_colnames
    colnames(point_C2S_2) <- point_colnames
    point_C2S_ <- rbind(point_C2S_1, point_C2S_1 )
    # Purge duplicates
    point_C2S <- point_C2S_[!duplicated(point_C2S_[,]),]
    
    # Do the same for the S2C direction
    point_S2C_1 <- 
        protocol_annotated_windows[
            protocol_annotated_windows$qd_samples_S2C>0,
            c("edge", "ipaddr1","port1","ipaddr2","port2",
              "windowed_qd_S2C","protocol1")]
    
    point_S2C_2 <- 
        protocol_annotated_windows[
            protocol_annotated_windows$qd_samples_S2C>0,
            c("edge", "ipaddr1","port1","ipaddr2","port2",
              "windowed_qd_S2C","protocol2")]
    
    colnames(point_S2C_1) <- point_colnames
    colnames(point_S2C_2) <- point_colnames
    point_S2C_ <- rbind(point_S2C_1, point_S2C_1 )
    # Purge duplicates
    point_S2C <- point_S2C_[!duplicated(point_S2C_[,]),]
    
    point_ <- rbind(point_C2S, point_S2C)
    # Purge duplicates
    point1 <- point_[ !duplicated( point_[,] ), ]
    point <- merge(point1, protocol_df, all.x=TRUE)
    
    ####### SEVERE DEBUG
#     y <- na.omit(point)
#     if( length(y[,1])!=length(point[,1]) )
#         handle_error("There are NA in point")
    
    
    x <- na.omit(host_proto_association)
    if( length(x[,1])!=length(host_proto_association[,1]) )
        handle_error("There are NA in host_proto_association")
    
    if (length( point_C2S[duplicated(point_C2S[,]),1] ) != 0
        | length( point_S2C[duplicated(point_S2C[,]),1] ) != 0 )
        handle_error("There are dulpicates in point_C2S or in point_S2C")
    
    ####### SEVERE DEBUG
    
    return(point)
}

build_logarithmic_protocol_scatterplot <- function(point, plot_file)
{
    png(plot_file, width = 700, height = 700)
    qds <- jitter(point$windowed_qd, amount=10)
    qds[qds<=1] <- 1
    plot(qds, jitter(x=point$proto_id, amount=0.3), log="x",
        lty="solid", cex=.4,
        col=rgb(0,0,0,alpha=2,maxColorValue=255), 
        pch=16)
    dev.off()    
}

build_non_logarithmic_protocol_scatterplot <- function(point, plot_file)
{
    png(plot_file, width = 700, height = 700)
    qds <- jitter(point$windowed_qd, amount=10)
    plot(qds, jitter(x=point$proto_id, amount=0.3),
         lty="solid", cex=.4,xlim=c(1, 800),
         col=rgb(0,0,0,alpha=2,maxColorValue=255), 
         pch=16)
    dev.off()    
}

calculate_point_df <- function(filelist)
{
    # To unify the qd and the percentiles of all traces
    #calculate_global_stats(filelist)
    #get_global_stats()
    
    filename <- filelist[1]
    print("Processing file:")
    print(filename)
    windows_ <-load_window_log(filename)
    point <- get_point(windows_)
    
    for (filename in filelist[2:length(filelist)])
    {
        print("Processing file:")
        print(filename)
        windows_ <- load_window_log(filename)
        point <- rbind(point, get_point(windows_))
    }
    
    print("Saving point")
    save(point, file=point_savefile)
}


filelist <- list.files(path = log_file_folder, 
                       pattern = "*log_tcp_windowed_qd_acktrig", all.files = FALSE,
                       full.names = TRUE, recursive = TRUE,
                       ignore.case = FALSE, include.dirs = FALSE)


print("Loading point")
load(point_savefile)
print("Building the plot")
build_non_logarithmic_protocol_scatterplot(point, proto_scatterplot_file)


