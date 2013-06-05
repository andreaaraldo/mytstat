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

class_assoc <- data.frame(
    protocol = c(0, 1, 2, 6, 8, 32, 33, 64, 128, 256, 
               257, 1024, 2048, 4096, 8192, 16384, 16416, 16640, 24576, 
               32768, 65536, 81920, 131072, 147456),
    class = c("OTHER", "WEB", "VOIP", "VOIP", "CHAT", "CHAT", "CHAT", "CHAT", "CHAT", "P2P",
               "P2P", "MAIL", "MAIL", "MAIL", "OTHER", "P2P", "OTHER", "P2P", "OTHER",
               "SSH", "MEDIA", "OTHER", "P2P", "P2P")
    )

con <- file(r_logfile)
sink(con, append=TRUE)
sink(con, append=TRUE, type="message")


handle_warning <- function(w, function_name)
{
    print(paste( "WARNING in ", function_name ) )
    warning(w)
}

handle_error <- function(e, function_name)
{
    print(paste( "ERROR in ", function_name ) )
    stop(e)
}


tryCatch({
    library(plyr)
    require(ggplot2)
    require(ff)
    require(ffbase)
    require(reshape)
}
         ,warning=function(w){handle_warning(w,"")}
         ,error=function(e){handle_error(e,"")}
)



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
        
        ####### SEVERE DEBUG: begin
        if( length( outgoing_windows[ is.na(outgoing_windows$ipaddr) |
                                          outgoing_windows$edge==0, 1 ] ) != 0 ){
            stop("invalid values in outgoing_windows")
        }
        ####### SEVERE DEBUG: end
            
        
        protocol_column <- 
            sapply(strsplit(as.character(outgoing_windows$type),":"), "[[", 1)
        outgoing_windows$protocol <- as.numeric(protocol_column)
        outgoing_windows$type <- NULL
        return(outgoing_windows)
    },
             warning=function(w){handle_warning(w,"get_outgoing_windows(..)")},
             error=function(e){handle_error(e,"get_outgoing_windows(..)")}
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
        outgoing_windows_ff <- as.ffdf(outgoing_windows_)
        
#         outgoing_windows_ff <- 
#             ffdf(edge=ff(outgoing_windows_$edge), 
#                  ipaddr=ff(outgoing_windows_$ipaddr),
#                  port=ff(outgoing_windows_$port),
#                  protocol = ff(outgoing_windows_$protocol),
#                  windowed_qd = ff(outgoing_windows_$windowed_qd),
#                  class = ff(outgoing_windows_$class)
#             )
#         
        ####### SEVERE DEBUG: begin
        num_of_na_rows <- length( 
            outgoing_windows_[is.na(outgoing_windows_$edge) | outgoing_windows_$edge==0 |
                                  is.na(outgoing_windows_$ipaddr) | 
                                  is.na(outgoing_windows_$class) , 1] )
        if(num_of_na_rows != 0)
        {
            print(paste("convert_to_windows_ff(..): num_of_na_rows=",num_of_na_rows))
            stop("convert_to_windows_ff(..): There are forbidden NA in windows_")
        } 
        
        idx <- ffwhich(outgoing_windows_ff, edge==0 | is.na(ipaddr))
        len <- length( idx )
        if( len != 0 ){
            stop(paste( "There are",len,"invalid values in outgoing_windows") )
        }
        
        ####### SEVERE DEBUG: end
        
        return(outgoing_windows_ff)
    }, 
             warning = function(w){handle_warning(w, "convert_to_outgoing_windows_ff(..)")},
             error = function(e) {handle_error(e, "convert_to_outgoing_windows_ff(..)")}
             
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
            
            outgoing_windows_ff <- NULL
            iteration <- 1
            upper_bound <- filelist_size
            repeat{
                filename <- filelist[iteration]
                print(paste("calculate_window_df(..): Extracting points from file:",
                            filename) )
                windows_ <- load_window_log(filename)
                outgoing_windows_1 <- get_outgoing_windows(windows_)
                outgoing_windows_ <- 
                    merge( outgoing_windows_1, traffic_classassoc, 
                           by.x="protocol", by.y="protocol", all.x=TRUE)
                
                ####### SEVERE DEBUG: begin
                len <- length(outgoing_windows_[,1] )
                print(paste("calculate_window_df(..): Number of windows found ",
                            "in the last file: ",len) )
                windows_found_until_now <- windows_found_until_now + len
                
                if( length( outgoing_windows_[ is.na(outgoing_windows_$class), 1] )>0 ){
                    print( head( outgoing_windows_[ is.na(outgoing_windows_$class), ] ) )
                    stop("There are protocols associated to no class")
                }
                
                # print("calculate_outgoing_windows_df(..): outgoing_windows_")
                # print( head( outgoing_windows_[outgoing_windows_$protocol==1024,] ) )
                ####### SEVERE DEBUG: end
                
                outgoing_windows_ff_ <- convert_to_outgoing_windows_ff(outgoing_windows_)
                
                if( iteration==1 ){
                    outgoing_windows_ff <- outgoing_windows_ff_
                }else{
                    outgoing_windows_ff <- 
                        ffdfappend( outgoing_windows_ff, 
                                    outgoing_windows_ff_, adjustvmode=F)
                }
                
                ######## SEVERE DEBUG: begin
                len <-length(outgoing_windows_ff[,1] )
                print(paste("calculate_window_df(..): The length of outgoing_windows_ff is now: ",
                            len) )
                if(windows_found_until_now != len )
                    stop("calculate_window_df(..): lengths are different")
                
                idx <- ffwhich(outgoing_windows_ff, edge==0 | is.na(ipaddr))
                len <- length( idx )
                if( len != 0 ){
                    stop(paste( "There are",len,"invalid values in outgoing_windows") )
                }
                ######## SEVERE DEBUG: end
                
                iteration <- iteration + 1
                if( iteration > upper_bound){
                    break
                }
            }
            
            print("calculate_window_df(..): Saving windows_ff")
            ffsave(outgoing_windows_ff, file=window_savefile)
        }        
    },
             warning = function(w){handle_warning(w, "calculate_outgoing_windows_df(..)") },
             error = function(e){handle_error(e, "calculate_outgoing_windows_df(..)")}
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
        
        print( paste( "extract_time_window(..): extracting rows with",
                      "edge between",left_edge,"and",right_edge) )
        
        idx <- ffwhich(dataframeff, edge >= left_edge & edge <= right_edge)
        if( is.null(idx) ) {
          idx <- as.numeric( array( dim=c(0) ) )
        }

        returndf_ff <- dataframeff[ idx, ]
        
        #    subset.ffdf ( dataframeff, dataframeff$edge >= left_edge &
        #                                 dataframeff$edge <= right_edge)
        return(as.data.frame(returndf_ff) )
    },
             warning = function(w){handle_warning(w, "extract_time_window(..)")},
             error = function(e){handle_error(e, "extract_time_window(..)")}
    )
    
}

# It's a wrapper of calculate_outgoing_windows_df(..)
build_outgoing_windows_df <- function()
{
    tryCatch({
        filelist <- list.files(path = log_file_folder, 
                               pattern = "*log_tcp_windowed_qd_acktrig", 
                               all.files = FALSE,full.names = TRUE, recursive = TRUE,
                               ignore.case = FALSE, include.dirs = FALSE)
        
        print("Calculating outgoing_windows_ff")
        calculate_outgoing_windows_df(filelist)
        
        print(paste("outgoing_windows_ff saved in file ",window_savefile) )    
        
        ####### SEVERE DEBUG: begin
        ffload(file=window_savefile, overwrite=TRUE)
        
        idx <- ffwhich(outgoing_windows_ff, edge==0 | is.na(ipaddr))
        len <- length( idx )
        if( len != 0 ){
            stop(paste( "There are",len,"invalid values in outgoing_windows") )
        }
        ####### SEVERE DEBUG: end
    },
             warning = function(w){handle_warning(w,"build_outgoing_windows_df(..)")},
             error = function(e){handle_error(e,"build_outgoing_windows_df(..)")}
    )
}

plot_class_distinguished_frequency_plots <- function()
{
    tryCatch({
        print("Loading outgoing_windows_ff")
        # (windows_ff has been created by build_outgoing_windows_df() )
        ffload(file=window_savefile, overwrite=TRUE)
        # Now, the variable outgoing_windows_ff is available
        
        
        #### Interval [100,1000[
        idx <- ffwhich(outgoing_windows_ff, !is.na(windowed_qd) &
                       windowed_qd >= 100 & windowed_qd < 1000)
        if( is.null(idx) ) {
            idx <- as.numeric( array( dim=c(0) ) )
        }
        filtered_outgoing_windows <- as.data.frame( outgoing_windows_ff[idx,] )
        head(filtered_outgoing_windows)
        q <- qplot( factor(protocol), data=filtered_outgoing_windows, geom="bar", log="y")
        q + opts(axis.text.x=theme_text(angle=-90))
        
        #### Interval [1000,+infty[
        idx <- ffwhich(outgoing_windows_ff, !is.na(windowed_qd) &
                           windowed_qd >= 1000)
        if( is.null(idx) ) {
            idx <- as.numeric( array( dim=c(0) ) )
        }
        filtered_outgoing_windows <- as.data.frame( outgoing_windows_ff[idx,] )
        head(filtered_outgoing_windows)
        q <- qplot( factor(protocol), data=filtered_outgoing_windows, geom="bar", log="y")
        q + opts(axis.text.x=theme_text(angle=-90))
        
        #### Interval [0,100[
        idx <- ffwhich(outgoing_windows_ff, !is.na(windowed_qd) &
                           windowed_qd < 100)
        if( is.null(idx) ) {
            idx <- as.numeric( array( dim=c(0) ) )
        }
        filtered_outgoing_windows <- as.data.frame( outgoing_windows_ff[idx,] )
        head(filtered_outgoing_windows)
        q <- qplot( factor(protocol), data=filtered_outgoing_windows, geom="bar", log="y")
        q + opts(axis.text.x=theme_text(angle=-90))
    },
             warning = function(w){
                 handle_warning(w,"plot_class_distinguished_frequency_plots()")},
             error = function(e){
                 handle_error(e,"plot_class_distinguished_frequency_plots()") }
    )
}

get_class_spread_over_qd_category <- function(outgoing_windows_ff){
    tryCatch({
        idx <- ffwhich(outgoing_windows_ff, !is.na(windowed_qd) )
        tot <- length(idx)
        outgoing_windows_ff_clean <-outgoing_windows_ff[idx,]
        
        spread_over_qd_category <- NULL
        iteration <- 1
        for(traffic_class_ in as.character(levels( class_assoc$class) ) ){
            
            print( paste( "Looking for class ",traffic_class_) )
            idx <- ffwhich(outgoing_windows_ff_clean, class==traffic_class_ )
            if( is.null(idx) ) {
                idx <- as.numeric( array( dim=c(0) ) )
            }
            tot_of_that_class <- length(idx)
            print( paste( "Found ",tot_of_that_class,"windowed qd of class", traffic_class_ ) )
            filtered_outgoing_windows <-outgoing_windows_ff_clean[idx,]
            idx <- ffwhich(filtered_outgoing_windows, windowed_qd<100 )
            low_ <- length(idx)
            idx <- ffwhich(filtered_outgoing_windows, windowed_qd>=100 & windowed_qd<1000)
            mid_ <- length(idx)
            idx <- ffwhich(filtered_outgoing_windows, windowed_qd>=1000)
            hig_ <- length(idx)
    
            digits_ <- 1
            spread_over_qd_category_ <- 
                data.frame(traffic_class=traffic_class_, low=low_, 
                           mid=mid_, hig=hig_, tot=tot_of_that_class,
                           low_perc=round( (low_/tot_of_that_class)*100, digits=digits_),
                           mid_perc=round( (mid_/tot_of_that_class)*100, digits=digits_),
                           hig_perc=round( (hig_/tot_of_that_class)*100, digits=digits_ ),
                           overall_perc = round( (tot_of_that_class / tot)*100 ) )
            
            if(iteration==1){
                spread_over_qd_category <- spread_over_qd_category_
            }else{
                spread_over_qd_category <- 
                    rbind( spread_over_qd_category, spread_over_qd_category_ )
            }
            
            iteration <- iteration +1
        }
        
        # Overall statistics
        spread_over_qd_category_ <- 
            data.frame(traffic_class="OVERALL", 
                       low=sum(spread_over_qd_category$low), 
                       mid=sum(spread_over_qd_category$mid),
                       hig=sum(spread_over_qd_category$hig),
                       tot=sum(spread_over_qd_category$tot),
                       low_perc=( sum(spread_over_qd_category$low)/tot )*100,
                       mid_perc=( sum(spread_over_qd_category$mid)/tot )*100,
                       hig_perc=( sum(spread_over_qd_category$hig)/tot )*100,
                       overall_perc= sum(spread_over_qd_category$overall_perc) )
        
        spread_over_qd_category <- 
            rbind( spread_over_qd_category, spread_over_qd_category_ )
        
        print(spread_over_qd_category)
    },
             warning = function(w){
                 handle_warning(w,"get_class_spread_over_qd_category()")},
             error = function(e){
                 handle_error(e,"get_class_spread_over_qd_category()") }
    )
    
}

# Return the rows in dataframe1 and dataframe2 that are not in both dataframes
# inspired by http://stackoverflow.com/a/10907485/2110769
difference <- function(dataframe1, dataframe2)
{
    tryCatch({
        print("dataframe1 (incomplete)")
        print( class(dataframe1) )
        print(dataframe1 )
        print("dataframe2")
        print( class(dataframe2) )
        print(dataframe2 )
        union <- rbind(dataframe1, dataframe2)
        
        print("union")
        print( class( union ) )
        print(union)
        
        # We use the projection to extrapolate the indexes of the rows that will fall
        # in the result, in order to let the duplicated(..) function work only on few
        # columns in order to reduce the computational load
        union_projection <- subset(union, select=c('edge', 'ipaddr', 'port') )
        print("union_projection")
        print(union_projection )
        
        difference_idx <- ffwhich(union_projection, 
                                   !duplicated(x=union_projection, fromLast = FALSE) & 
                                       !duplicated(x=union_projection, fromLast = TRUE) )
#     
#         difference_idx <- 
#             !duplicated(union_projection,fromLast = FALSE) & 
#             !duplicated(union_projection,fromLast = TRUE)
#         print("difference_idx")
#         print(difference_idx )
        
        difference_df <- union[difference_idx,]
        
        print("difference_df")
        print( class(difference_df) )
        print(difference_df)
        return(difference_df)
    },
             warning = function(w){handle_warning(w, "difference(..)")},
             error = function(e){handle_error(e, "difference(..)")}
    )
}

get_proto_influence <- function(outgoing_windows_ff)
{
    tryCatch({
        influenced_point_colnames <- 
            c('edge', 'ipaddr', 'port', 'protocol', 'windowed_qd', 'influencing_class')
        ####### SEVERE DEBUG: begin
        rownames <- row.names(outgoing_windows_ff)
        if( !is.null( rownames ) ) {
            print( "row_names of outgoing_windows_ff are" )
            print(rownames)
            stop( "rownames must be NULL." )
        }
            
        ####### SEVERE DEBUG: begin
        
        outgoing_windows_ff_ord <- outgoing_windows_ff
        
        print("outgoing_windows_ff_ord")
        print( outgoing_windows_ff_ord )
        
        outgoing_windows_ff_1 <- ffdf(edge=outgoing_windows_ff_ord$edge, 
                                      ipaddr=outgoing_windows_ff_ord$ipaddr,
                                      influencing_port=outgoing_windows_ff_ord$port,
                                      influencing_proto=outgoing_windows_ff_ord$proto,
                                      influencing_class=outgoing_windows_ff_ord$class)
        
        merged <- merge(x=outgoing_windows_ff_ord, y=outgoing_windows_ff_1, 
                        by.x=c('edge','ipaddr'),by.y=c('edge','ipaddr') )
        merged_ff <- merged
        idx <- ffwhich(merged_ff, port != influencing_port )
        influence <- merged_ff[idx,]
        print("")
        print("")
        print("influence")
        print(influence )
        
        
        traffic_class <- "WEB"
        idx <- ffwhich(influence, influencing_class==traffic_class )

        print("")
        print("")
        print("influenced_by_class of class")
        influenced_by_class_verbose <- influence[idx,]
        print( class(influenced_by_class_verbose) )
        print(influenced_by_class_verbose)
        
        influenced_by_class_projected_on_outgoing_windows_cols <- 
            subset(influenced_by_class_verbose, select=colnames(outgoing_windows_ff) )
        print("")
        print("")
        print("influenced_by_class_projected_on_outgoing_windows_cols")
        print( class(influenced_by_class_projected_on_outgoing_windows_cols) )
        print(influenced_by_class_projected_on_outgoing_windows_cols)
        
        # Get rid of all the useless columns
        influenced_by_class <- subset( influenced_by_class_verbose, 
                                       select=influenced_point_colnames )
        
        non_influenced_by_class <-
            difference( outgoing_windows_ff_ord , 
                        influenced_by_class_projected_on_outgoing_windows_cols )
        print("non_influenced_by_class prima di sostituzione")
        print(non_influenced_by_class)
        
        non_influenced_by_class <- as.data.frame(non_influenced_by_class)
        non_influenced_by_class$influencing_class <- paste(traffic_class,"NO",sep="_")
        non_influenced_by_class$class <- NULL
        print("non_influenced_by_class dopo di sostituzione")
        print(non_influenced_by_class)
        
        #column_to_insert <- as.ff( factor(paste(traffic_class,"NO",sep="_") ) )
        print(column_to_insert )
        non_influenced_by_class[,c('class')] <- column_to_insert
        
        
        influenced_points_ <- rbind( influenced_by_class, non_influenced_by_class )
        
        print("")
        print("")
        print("influenced_points_")
        print(length( influenced_points_[,1] ) )
        print(influenced_points_[,])
        
    },
             warning = function(w){handle_warning(w, "get_proto_influence(..)")},
             error = function(e){handle_error(e, "get_proto_influence(..)")}
    )
    
}

tryCatch({
    print("Loading outgoing_windows_ff")
    build_outgoing_windows_df()
    # (windows_ff has been created by build_outgoing_windows_df() )
    ffload(file=window_savefile, overwrite=TRUE)
    # Now, the variable outgoing_windows_ff is available
    ####### SEVERE DEBUG: begin
    idx <- ffwhich(outgoing_windows_ff, edge==0 | is.na(ipaddr))
    len <- length( idx )
    if( len != 0 ){
        stop(paste( "There are",len,"invalid values in outgoing_windows") )
    }
    ####### SEVERE DEBUG: end
    
    idx<-fforder(outgoing_windows_ff$edge, outgoing_windows_ff$ipaddr)
    outgoing_windows_ff_ord <- outgoing_windows_ff[idx ,]
    outgoing_windows_ff_ord_subsetted <- as.ffdf(outgoing_windows_ff_ord[1:5,] )
    row.names(outgoing_windows_ff_ord_subsetted) <- NULL
    get_proto_influence( outgoing_windows_ff_ord_subsetted )
    
    ## Extract time window
    step = 5 #(minutes)
    left_date <- "2007-06-20 23:21:09"
    right_date <- "2007-06-21 23:32:32"
    
    left_edge <- as.numeric(
        strptime(left_date, format="%Y-%m-%d %H:%M:%S") )
    right_edge <- as.numeric(
        strptime(right_date, format="%Y-%m-%d %H:%M:%S") )
    
    print( paste("The initial left_edge is", left_edge) )
    
    idx <- ffwhich(outgoing_windows_ff, !is.na(windowed_qd) )
    if( is.null(idx) ) {
        idx <- as.numeric( array( dim=c(0) ) )
    }
    clean_outgoing_windows_ff <- outgoing_windows_ff[idx,]
    left_edge <- min(clean_outgoing_windows_ff[,1] )
    print(paste( "The first edge is", left_edge) )
    
    right_edge <- left_edge + 60*60*24
    
    print("Extracting windows")
    quantiles <- NULL
    iteration <- 1
    repeat
    {
        extracted_windows <- extract_time_window(
            outgoing_windows_ff, left_edge, step)
        print(paste("Number of windows extracted between",left_edge,"and",right_edge,sep=" "))
        print(length(extracted_windows[,1]))
        
        new_quantiles <- t( quantile(extracted_windows$windowed_qd,
                                  c(.50,.90,.95,.99), na.rm = TRUE) )
        new_quantiles <- cbind(left_edge, new_quantiles)
        
        #new_quantiles$left_edge <- left_edge
        print("new_quantiles is")
            
        print( head(new_quantiles) )
        if(iteration ==1){
            quantiles <- new_quantiles
        }else{
            quantiles <- rbind( quantiles, new_quantiles)
        }
        
        print("Now quantiles is")
        print(quantiles)
        
        
        left_edge <- left_edge+step*60
        iteration <- iteration+1
        
        if(left_edge > right_edge){
            break
        }
    }
    quantiles_df <- data.frame(quantiles)
    quantiles_df <- na.omit(quantiles_df)
    
    #Inspired by: http://stackoverflow.com/a/4877936/2110769
    quantiles_df <- melt( quantiles_df, id="left_edge", variable_name = 'quantiles')
    ggplot(quantiles_df, aes(left_edge,value)) + geom_line(aes(colour = quantiles))
    
},
         warning = function(w){handle_warning(w, ",main execution")},
         error = function(e){handle_error(e, ",main execution")}
)
