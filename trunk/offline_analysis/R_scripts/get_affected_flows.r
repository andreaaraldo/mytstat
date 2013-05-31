####### CONSTANTS
log_file_folder <- "/home/araldo/analysis_output" #log files produced by tstqt
save_folder <- "/home/araldo/temp/r_out"
r_logfile <- paste(save_folder,"r.log",sep="/")
percentiles_cdf_plot <- paste(save_folder,"percentiles_cdf.jpg",sep="/")
qd_pdf_plot <- paste(save_folder,"qd_pdf.jpg",sep="/")
proto_scatterplot_file <- paste(save_folder,"scatter.png",sep="/")
percentiles_savefile <- paste(save_folder,"percentiles.R.save",sep="/")
point_savefile <- paste(save_folder,"point.R.save",sep="/")
window_savefile <- paste(save_folder,"windows.R.save",sep="/")
qd_of_flows_to_study_savefile <- 
    paste(save_folder,"qd_flows_to_study.R.save",sep="/")
chosen_qd_threshold <- 0
chosen_flow_length_threshold <- 0

field_names<-c("edge", "ipaddr1","port1","ipaddr2","port2",
               "C_internal", "S_internal",
               
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



con <- file(r_logfile)
sink(con, append=TRUE)
sink(con, append=TRUE, type="message")


tryCatch({
    library(plyr)
    require(ggplot2)
    require(ff)
    require(ffbase)
    
    proto_name <- as.character( c(
        "UNKNOWN", "HTTP", "RTSP", "RTP", "ICY", "RTCP", "MSN", "YMSG",
        "XMPP", "P2P", "SKYPE", "SMTP", "POP3", "IMAP", "SSL", "OBF",
        "SSH", "RTMP", "MSE", "MSE+OBF", "P2P+OBF", "P2P+HTTP",
        "MSN+HTTP", "RTP+RTSP", "MSN+OBF"
    ) )
    
    # These are the values associated to the protocols by tstat/protocol.h
    protocol <- c(
        0, 1, 2, 4, 8, 16, 32, 64,
        128, 256, 512, 1024, 2048, 4096, 8192, 16384,
        32768, 65536, 131072, 147456, 16640, 257,
        33, 6, 16416
    )
    
}
         ,warning=function(w){handle_warning(w)}
         ,error=function(e){stop(e)}
)

handle_warning <- function(w)
{
    warning(w)
}

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



get_outgoing_windows <- function(windows)
{
    tryCatch({
        print( paste( "Extracting outgoing windows from ", 
                      length(windows[,1] ), "windows " ) )
        outgoing_window_colnames_temp <- 
            c("edge", "ipaddr","port","type","windowed_qd")
        
        internal_client_windows <- 
            windows[ windows$C_internal==1 & windows$S_internal==0,
                     c("edge","ipaddr1", "port1", "type_C2S","windowed_qd_C2S")]
        colnames(internal_client_windows) <- outgoing_window_colnames_temp
        print( paste( "There are ", 
                      length(internal_client_windows[,1] ), " cli windows" ) )
        
        
        internal_server_windows <- 
            windows[ windows$S_internal==1 & windows$C_internal==0,
                     c("edge","ipaddr2", "port2", "type_S2C","windowed_qd_S2C")]
        colnames(internal_server_windows) <- outgoing_window_colnames_temp
        print( paste( "There are ", 
                      length(internal_server_windows[,1]), " srv windows" ) )
        
        outgoing_windows <- 
            rbind(internal_client_windows, internal_server_windows)
        
        protocol_column <- 
            sapply(strsplit(as.character(outgoing_windows$type),":"), "[[", 1)
        outgoing_windows$protocol <- as.numeric(protocol_column)
        outgoing_windows$type <- NULL
        return(outgoing_windows)
    },
        warning=function(w){handle_warning(w)},
        error=function(e){
            print("ERROR in get_outgoing_windows(..)")
            stop(e)}
            )
}


build_logarithmic_protocol_scatterplot <- function(point, plot_file)
{
    png(plot_file, width = 700, height = 700)
    qds <- jitter(point$windowed_qd, amount=10)
    qds[qds<=1] <- 1
    plot(qds, jitter( x =as.numeric(factor(point$protocol) ) , amount=0.3), log="x",
        lty="solid", cex=.4,
        col=rgb(0,0,0,alpha=2,maxColorValue=255), 
        pch=16)
    dev.off()    
}

build_non_logarithmic_protocol_scatterplot <- function(point, plot_file)
{
    png(plot_file, width = 700, height = 700)
    qds <- jitter(point$windowed_qd, amount=10)
    plot(qds, jitter( x =as.numeric(factor(point$protocol) ) , amount=0.3),
         lty="solid", cex=.4,xlim=c(1, 800),
         col=rgb(0,0,0,alpha=2,maxColorValue=255), 
         pch=16)
    dev.off()    
}

# Build the point_df unifying all the point dataframes of the single
# tracks (each of which was obtained with get_point(windows), where windows
# are the windows of a single tracks). It saves point_df in the file
# point_savefile
calculate_point_df <- function(filelist)
{
    filename <- filelist[1]
    print(paste("Extracting points from file:",filename) )
    windows_ <-load_window_log(filename)
    point_ <- get_point(windows_)
    print(length(point_[,1]))
    pointff <- ffdf(edge=ff(point_$edge), windowed_qd=ff(point_$windowed_qd), 
                    protocol=ff( point_$protocol) )
    
    for (filename in filelist[2:length(filelist)])
    {
        print("Extracting points from file:")
        print(filename)
        windows_ <- load_window_log(filename)
        point_ <- get_point(windows_)
        print(length(point_[,1]))
        pointff_ <- ffdf(edge=ff(point_$edge), windowed_qd=ff(point_$windowed_qd), 
                         protocol=ff( point_$protocol) )
        pointff <- ffdfappend( pointff, pointff_, adjustvmode=F)
    }
    
    print("total length")
    print(length(as.data.frame(pointff)[,1] ) )
    
    print("Saving pointff")
    ffsave(pointff, file=point_savefile)
}

convert_to_outgoing_windows_ff <- function(outgoing_windows_)
{
    tryCatch({
        outgoing_windows_ff <- 
            ffdf(edge=ff(outgoing_windows_$edge), 
                 ipaddr=ff(outgoing_windows_$ipaddr),
                 port=ff(outgoing_windows_$port),
                 protocol = ff(outgoing_windows_$protocol),
                 windowed_qd = ff(outgoing_windows_$windowed_qd)
            )
        
        ####### SEVERE DEBUG: begin
        num_of_na_rows <- length( outgoing_windows_[is.na(outgoing_windows_$edge) ,1] )
        if(num_of_na_rows != 0)
        {
            print(paste("convert_to_windows_ff(..): num_of_na_rows=",num_of_na_rows))
            stop("convert_to_windows_ff(..): There are forbidden NA in windows_")
        }
        ####### SEVERE DEBUG: end
        
        return(outgoing_windows_ff)
    }, 
             warning = function(w){handle_warning(w)},
             error = function(e) {
                 print("ERROR in convert_to_outgoing_windows_ff(..)")
                 stop(e)
             }
             
    )
}



calculate_outgoing_windows_df <- function(filelist)
{
    tryCatch({
        ####### SEVERE DEBUG: begin
        windows_found_until_now <- 0
        ####### SEVERE DEBUG. end
        filelist_size <- length(filelist)
        if(filelist_size == 0)
            print("calculate_window_df(..): filelist is empty")
        else{
            print(paste("calculate_window_df(..) Found ",filelist_size,
                        " log files to analyze" ) )
            filename <- filelist[1]
            print(paste( "calculate_window_df(..): Extracting windows from file:",
                         filename) )
            windows_ <-load_window_log(filename)
            outgoing_windows_ <- get_outgoing_windows(windows_)
            
            ######## SEVERE DEBUG: begin
            len <- length(outgoing_windows_[,1] )
            print(paste("calculate_window_df(..): Number of windows found ",
                        "in the last file: ",len) )
            windows_found_until_now <- windows_found_until_now + len
            ######## SEVERE DEBUG: end
            
            outgoing_windows_ff <- convert_to_outgoing_windows_ff(outgoing_windows_)
            
            ####### SEVERE DEBUG: begin
            print("calculate_window_df(..): Trying to save")
            ffsave(outgoing_windows_ff, file=window_savefile)
            rm(outgoing_windows_ff)
            print("calculate_window_df(..): Trying to load outgoing_windows_ff")
            ffload(file=window_savefile, overwrite=TRUE)
            print("calculate_window_df(..): loaded")
            ####### SEVERE DEBUG: end
            upper_bound <- length(filelist)
            for (filename in filelist[2:upper_bound])
            {
                print(paste("calculate_window_df(..): Extracting points from file:",
                            filename) )
                windows_ <- load_window_log(filename)
                outgoing_windows_ <- get_outgoing_windows(windows_)
                
                ####### SEVERE DEBUG: begin
                len <- length(outgoing_windows_[,1] )
                print(paste("calculate_window_df(..): Number of windows found ",
                                          "in the last file: ",len) )
                windows_found_until_now <- windows_found_until_now + len
                ####### SEVERE DEBUG: end
                outgoing_windows_ff_ <- convert_to_outgoing_windows_ff(outgoing_windows_)
                
                outgoing_windows_ff <- ffdfappend( outgoing_windows_ff, 
                                                   outgoing_windows_ff_, adjustvmode=F)
            }
            
            print("calculate_window_df(..): Saving windows_ff")
            ffsave(outgoing_windows_ff, file=window_savefile)
            
            ######## SEVERE DEBUG: begin
            len <-length(outgoing_windows_ff[,1] )
            print(paste("calculate_window_df(..): The length of outgoing_windows_ff is now: ",
                        len) )
            if(windows_found_until_now != len )
                stop("calculate_window_df(..): lengths are different")
            ######## SEVERE DEBUG: end
        }        
    },
             warning = function(w){handle_warning(w) },
             error = function(e){
                 print("ERROR in calculate_outgoing_windows_df")
                 stop(e)
             }
    ) 
}



# Params
#   - dataframe should be of type ffdf (see ff package info)
#   - left_edge: timestamp in seconds
#   - length: the length of the time window (in minutes) you want to extract
# Returns:
#   - a normal dataframe
# 
# In dataframe a column called "edge" must exist
extract_time_window <- function(dataframeff, left_edge, length)
{
    tryCatch({
        right_edge <- left_edge + length*60
        
        idx <- ffwhich(dataframeff, edge >= left_edge & edge <= right_edge)
        if( is.null(idx) ) {
          idx <- as.numeric( array( dim=c(0) ) )
        }

        returndf_ff <- dataframeff[ idx, ]
        
        #    subset.ffdf ( dataframeff, dataframeff$edge >= left_edge &
        #                                 dataframeff$edge <= right_edge)
        return(as.data.frame(returndf_ff) )
    },
             warning = function(w){handle_warning(w)},
             error = function(e){stop(e)}
    )
    
}


tryCatch({
    filelist <- list.files(path = log_file_folder, 
                           pattern = "*log_tcp_windowed_qd_acktrig", all.files = FALSE,
                           full.names = TRUE, recursive = TRUE,
                           ignore.case = FALSE, include.dirs = FALSE)
    
    print("Calculating outgoing_windows_ff")
    calculate_outgoing_windows_df(filelist)
    print(paste("outgoing_windows_ff saved in file ",window_savefile) )

    print("Loading outgoing_windows_ff")
    # (windows_ff has been created by calculate_window_df(filelist) )
    ffload(file=window_savefile, overwrite=TRUE)
    
    # Now, the variable windows_ff is available
    
    step = 120 #(minutes)
    left_date <- "2007-06-20 23:21:09"
    right_date <- "2007-06-21 23:32:32"
    
    left_edge <- as.numeric(
        strptime(left_date, format="%Y-%m-%d %H:%M:%S") )
    right_edge <- as.numeric(
        strptime(right_date, format="%Y-%m-%d %H:%M:%S") )
    

    print("Extracting windows")
    while(left_edge <= right_edge)
    {
        extracted_windows <- extract_time_window(windows_ff, left_edge, step)
        #print(paste("Number of windows extracted from",left_edge,"and",right_edge,sep=" "))
        #print(length(extracted_windows[,1]))
        left_edge <- left_edge+step
    }
    
},
         warning = function(w){handle_warning(w)},
         error = function(e){stop(e)}
)




