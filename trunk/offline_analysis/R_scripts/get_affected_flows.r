####### CONSTANTS
log_file_folder <- "/home/araldo/output_of_config_tester/Makefile.conf.5" #log files produced by tstqt
save_folder <- "/home/araldo/temp/r_out"
r_logfile <- paste(save_folder,"r.log",sep="/")
percentiles_plot <- paste(save_folder,"percentiles",sep="/")
percentile_table_file <- paste(save_folder,"percentile_table.txt",sep="/")
linear_class_scatterplot_file <- paste(save_folder,"scatter.eps",sep="/")
percentiles_savefile <- paste(save_folder,"percentiles.R.save",sep="/")
window_savefile <- paste(save_folder,"outgoing_windows_long.R.save",sep="/")
influence_point_savefile <- paste(save_folder,"influence_point.R.save",sep="/")
proto_influence_savefile <- paste(save_folder,"influence_scatter_point_table.txt",sep="/")
quantile_evolution_savefile <- paste(save_folder,"quantile_evolution.txt",sep="/")
merged_savefile <- paste(save_folder,"merged_long.R.save",sep="/")
qd_of_flows_to_study_savefile <- paste(save_folder,"qd_flows_to_study_long.R.save",sep="/")
chosen_qd_threshold <- 0
chosen_flow_length_threshold <- 0

field_names<-c("edge", "ipaddr1","port1","ipaddr2","port2",
               "C_internal", "S_internal",
               
#                "type_C2S",
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
sink(con, append=FALSE)
sink(con, append=FALSE, type="message")

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

# To calculate the empirical complementary cdf
# see https://stat.ethz.ch/pipermail/r-help/2007-May/133006.html
eccdf <- function(x)
{
    tryCatch({
        x <- sort(x)
        n <- length(x)
        if (n < 1)
            stop("'x' must have 1 or more non-missing values")
        vals <- sort(unique(x))
        rval <- approxfun(vals, 1-cumsum(tabulate(match(x, vals)))/n, #[CHANGED]
                          method = "constant", yleft = 1, yright = 0, f = 0, ties = "ordered")
        class(rval) <- c("eccdf", "stepfun", class(rval)) #[CHANGED]
        attr(rval, "call") <- sys.call()
        rval 
    },
             warning=function(w){handle_warning(w,"eccdf(..)")},
             error=function(e){handle_error(e,"eccdf(..)")} 
    )
}
plot.eccdf_useless <- function (x, ..., ylab = "1-Fn(x)", verticals = FALSE,
                        col.01line = "gray70") #CHANGED
{
    tryCatch({
        plot.stepfun(x, ..., ylab = ylab, verticals = verticals)
        abline(h = c(0, 1), col = col.01line, lty = 2)
    },
             warning=function(w){handle_warning(w,"plot.eccdf(..)")},
             error=function(e){handle_error(e,"plot.eccdf(..)") }
    )
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

calculate_percentiles <- function()
{
    tryCatch( {
        filelist <- list.files(path = log_file_folder, 
                               pattern = "*log_tcp_windowed_qd_acktrig", 
                               all.files = FALSE,full.names = TRUE, recursive = TRUE,
                               ignore.case = FALSE, include.dirs = FALSE)
        
        flow_id_vector <- c("ipaddr","port","ipaddr_out","port_out")
        percentiles <- NULL
        
        iteration <- 1
        repeat{
            filename <- filelist[iteration]
            print( paste( "Calculating percentiles for file ",filename) )
            windows_ <-load_window_log(filename)
            outgoing_windows_ <- get_outgoing_windows(windows=windows_)
            
            # Take all the non empty windows and project the resulting
            # dataframe on the columns that characterize a flow
            #all_non_empty_flows_ <-subset(outgoing_windows_, !is.na(windowed_qd), 
            #                              select(flow_id_vector) )
            
            # Find the flows with at least 1 non empty window. For each of them
            # calculate how many non empty windows are observed
            #all_non_empty_flows <- 
            #    ddply(all_non_empty_flows_, .(ipaddr,port,ipaddr_out, port_out), 
            #          summarise, non_empty_win_count=length(port) 
            #    )
            
            ####### Consider only the flows that are long enough
            #long_flows <- subset(all_non_empty_flows, 
            #                     non_empty_wins_count >= flow_length_threshold)
            
            ####### Per flow percentiles
            percentiles_df_ <- 
                ddply(outgoing_windows_, .(ipaddr, port, ipaddr_out, port_out), 
                      summarize,
                      percentile_50 = quantile( windowed_qd, na.rm=TRUE, c(.50)),
                      percentile_90 = quantile( windowed_qd, na.rm=TRUE, c(.90)),
                      percentile_95 = quantile( windowed_qd, na.rm=TRUE, c(.95)),
                      percentile_99 = quantile( windowed_qd, na.rm=TRUE, c(.99))
                )
            
            if(iteration == 1){
                percentiles_df <- percentiles_df_
            }else{
                percentiles_df <- rbind( percentiles_df, percentiles_df_ )
            }
            
            iteration <- iteration +1
            if(iteration > length(filelist)){
                break
            }
        }
        write.table(x=percentiles_df, percentile_table_file)
        return(percentiles_df)
    },
              warning=function(w){handle_warning(w,"calculate_percentiles(..)")},
              error=function(e){handle_error(e,"calculate_percentiles(..)")}
    )
}

plot_percentiles <- function()
{
    tryCatch({
        percentiles<-read.table(percentile_table_file)
        max_x <- 5000
        
        print("Generating cdf plot")
        plot_file <- paste(percentiles_plot,"cdf","eps",sep='.')
        postscript(plot_file, horizontal = FALSE,width=6,height=5)
        
        plot(ecdf(percentiles[,c("percentile_50")]), 
             log="x", xlim=c(1,max_x), col="red", 
             xlab="aggregated queueing delays (ms)",
             ylab="CDF", main=" "
             )
        
        plot(ecdf(percentiles[,c("percentile_90")]), 
             xlim=c(1,max_x), col="green", add=TRUE )
        
        plot(ecdf(percentiles[,c("percentile_95")]), 
              xlim=c(1,max_x), col="skyblue", add=TRUE )
         
        plot(ecdf(percentiles[,c("percentile_99")]), 
              xlim=c(1,max_x), col="violet", add=TRUE )
         legend('topleft',
                c("50%-percentile","90%-percentile", "95%-percentile", "99%-percentile"),
                lty=1, col=c("red","green","skyblue","violet"), bty='n', cex=.75)
        
        grid()
        dev.off()
        
        
        print("Generating complementary cdf plot")
        plot_file <- paste(percentiles_plot,"inverse_cdf","eps",sep='.')
        
        postscript(plot_file, horizontal = FALSE,width=6,height=5)
        
        plot(eccdf(percentiles[,c("percentile_50")]), 
             log="x", xlim=c(1,max_x), col="red", 
             xlab="aggregated queueing delays (ms)",
             ylab="complementary CDF", main=" "
        )
        
        plot(eccdf(percentiles[,c("percentile_90")]), 
             xlim=c(1,max_x), col="green", add=TRUE )
        
        plot(eccdf(percentiles[,c("percentile_95")]), 
             xlim=c(1,max_x), col="skyblue", add=TRUE )
        
        plot(eccdf(percentiles[,c("percentile_99")]), 
             xlim=c(1,max_x), col="violet", add=TRUE )
        legend('topleft',
               c("50%-percentile","90%-percentile", "95%-percentile", "99%-percentile"),
               lty=1, col=c("red","green","skyblue","violet"), bty='n', cex=.75)
        
        grid()
        dev.off()
        
        print( paste( "The plots are: ",percentiles_plot,"*") )
    },
             warning=function(w){handle_warning(w,"plor_percentiles(..)")},
             error=function(e){handle_error(e,"plot_percentiles(..)")}
    )   
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

process_logfile_useless <- function(filename)
{
    windows_ <-load_window_log(filename)
    
    result <- process_windows(
        windows=windows_[,], 
        qd_threshold=chosen_qd_threshold, 
        flow_length_threshold=chosen_flow_length_threshold)
    
    return(result)
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
            c("edge", "ipaddr","port","ipaddr_out","port_out","type","windowed_qd")
        
        internal_client_windows <- 
            windows[ windows$C_internal==1 & windows$S_internal==0,
                     c("edge","ipaddr1", "port1", "ipaddr2", "port2", "type_C2S","windowed_qd_C2S")]
        colnames(internal_client_windows) <- outgoing_window_colnames_temp
        print( paste( "There are ", 
                      length(internal_client_windows[,1] ), " cli windows" ) )
                
        internal_server_windows <- 
            windows[ windows$S_internal==1 & windows$C_internal==0,
                     c("edge","ipaddr2", "port2","ipaddr1", "port1", "type_S2C","windowed_qd_S2C")]
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
        
        neglected_windows <- 
            windows[ (windows$S_internal==1 & windows$C_internal==1) | 
                         (windows$S_internal==0 & windows$C_internal==0),
                     c("edge","ipaddr2", "port2","ipaddr1", "port1", "type_S2C","windowed_qd_S2C")]
        print( paste( "There are ", 
                      length(neglected_windows[,1]), " windows with both client ",
                      "and server internal or external. These will be ignored") )
        
        if(length(internal_client_windows[,1]) + length(internal_server_windows[,1]) +
               length(neglected_windows[,1]) != length(windows[,1] )){
            stop("The sum of neglected windows, internal client windows and internal server windows is not the total windows")
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

build_class_scatterplots <- function()
{
    tryCatch({
        
        print("Loading outgoing_windows_ff")
        ffload(file=window_savefile, overwrite=TRUE)
        # Now, the variable outgoing_windows_ff is available
        
        
        outgoing_windows_ff_clean <- as.data.frame(outgoing_windows_ff)
        outgoing_windows_ff_clean <-
            outgoing_windows_ff_clean[!is.na(outgoing_windows_ff_clean$windowed_qd), ]
        
        # see: http://www.r-bloggers.com/preparing-plots-for-publication/
#         filename <- paste(linear_class_scatterplot_file, "linear","png", sep='.')
#         pl <- qplot(class, windowed_qd, data=outgoing_windows_ff_clean, geom="jitter", 
#                     alpha=I(1/5))
#         print("Plot generated")
#         ggsave(plot=pl, file=filename, dpi=75)
#         print( paste("plot saved to file",filename) )
        
        filename <- paste(linear_class_scatterplot_file, "log","png", sep='.')
        pl <- qplot(class, windowed_qd, data=outgoing_windows_ff_clean, geom="jitter", 
                    alpha=I(1/5), log="y")
        ggsave(plot=pl, file=filename, dpi=75)
        print( paste("plot saved to file",filename) )
    },
             warning=function(w){handle_warning(w,"build_linear_class_scatterplot(..)")},
             error=function(e){handle_error(e,"build_linear_class_scatterplot(..)")}
    )
}


build_frequency_plots <- function()
{
    tryCatch({
        # Frequency plot of the windowed_qd
        plot_file <- paste(save_folder,"qd_frequency.eps",sep="/")
        
        print("Loading outgoing_windows_ff")
        ffload(file=window_savefile, overwrite=TRUE)
        # Now, the variable outgoing_windows_ff is available
        
        idx <- ffwhich(outgoing_windows_ff, !is.na(windowed_qd) )
        outgoing_windows_ff_clean <-outgoing_windows_ff[idx,c("windowed_qd")]
        outgoing_windowed_qd_ <- as.data.frame(outgoing_windows_ff_clean)
        remove(outgoing_windows_ff)
        remove(outgoing_windows_ff_clean)
        remove(idx)
#         q <- qplot(outgoing_windowed_qd, geom="histogram",freq=FALSE,binwidth=10,
#                    xlim = c(0, 1000))
        mydataframe <- data.frame( outgoing_windowed_qd=outgoing_windowed_qd_)
        
        mean <- mean(mydataframe$outgoing_windowed_qd, na.rm=TRUE)
        labels <- data.frame(xposition=c(mean), yposition=c(0.07),label="mean" )
        # The trick to add the vertical line is taken from http://stackoverflow.com/a/5392378
        # The trick to add the label is http://stackoverflow.com/a/9081281
        # The trick to format the label is http://sape.inf.usi.ch/quick-reference/ggplot2/geom_vline
        q <- ggplot(mydataframe, aes(x=outgoing_windowed_qd)) +
            geom_histogram(aes(y=..count../sum(..count..)),binwidth = 10   )+
            ylab("frequency") + xlab("aggregated queueing delay (ms)") +
            ylim(0, 0.26)+
            scale_x_continuous(breaks = round(seq(0, 1000, by = 100),1), 
                               limits=c(0, 1000) )+
            geom_vline(aes(xintercept=mean ), linetype="dotted") +
            geom_text(data = labels, aes(x = xposition, y = yposition, label = label),
                      size=4, angle=90, vjust=-0.4, hjust=0)
        
        ggsave( plot_file, q, width = 6, height = 5 ) 
        print( paste("Plot saved in ",plot_file) )
        
        
        
        percentiles <-read.table(percentile_table_file)
        ybound = 0.07
        labelposition=c(0.04)
        
        # Frequency plot of the 50th percentile
        plot_file <- paste(save_folder,"frequency_50th_percentile.eps",sep="/")
        
        mean <- mean(percentiles$percentile_50, na.rm=TRUE)
        labels <- data.frame(xposition=c(mean), yposition=labelposition,label="mean" )
        q <- ggplot(percentiles, aes(x=percentile_50)) +
            geom_histogram(aes(y=..count../sum(..count..)),binwidth = 10   )+
            ylab("frequency") + xlab("50th percentile of aggregated queueing delay (ms)") +
            ylim(0, ybound)+
            scale_x_continuous(breaks = round(seq(0, 1000, by = 100),1), 
                               limits=c(0, 1000) ) +
            geom_vline(aes(xintercept=mean ), linetype="dotted") +
            geom_text(data = labels, aes(x = xposition, y = yposition, label = label),
                      size=4, angle=90, vjust=-0.4, hjust=0)
        
        ggsave( plot_file, q, width = 6, height = 5 ) 
        print( paste("Plot saved in ",plot_file) )
        
        
        # Frequency plot of the 90th percentile
        plot_file <- paste(save_folder,"frequency_90th_percentile.eps",sep="/")
        
        mean <- mean(percentiles$percentile_90, na.rm=TRUE)
        labels <- data.frame(xposition=c(mean), yposition=labelposition,label="mean" )
        q <- ggplot(percentiles, aes(x=percentile_90)) +
            geom_histogram(aes(y=..count../sum(..count..)),binwidth = 10   )+
            ylab("frequency") + xlab("90th percentile of aggregated queueing delay (ms)") +
            ylim(0, ybound)+
            scale_x_continuous(breaks = round(seq(0, 1000, by = 100),1), 
                               limits=c(0, 1000) )+
            geom_vline(aes(xintercept=mean ), linetype="dotted") +
            geom_text(data = labels, aes(x = xposition, y = yposition, label = label),
                      size=4, angle=90, vjust=-0.4, hjust=0)
        
        ggsave( plot_file, q, width = 6, height = 5 ) 
        print( paste("Plot saved in ",plot_file) )
        
        
        # Frequency plot of the 95th percentile
        plot_file <- paste(save_folder,"frequency_95th_percentile.eps",sep="/")
        
        mean <- mean(percentiles$percentile_95, na.rm=TRUE)
        labels <- data.frame(xposition=c(mean), yposition=labelposition,label="mean" )
        q <- ggplot(percentiles, aes(x=percentile_95)) +
            geom_histogram(aes(y=..count../sum(..count..)),binwidth = 10   )+
            ylab("frequency") + xlab("95th percentile of aggregated queueing delay (ms)") +
            ylim(0, ybound)+
            scale_x_continuous(breaks = round(seq(0, 1000, by = 100),1), 
                               limits=c(0, 1000) )+
            geom_vline(aes(xintercept=mean ), linetype="dotted") +
            geom_text(data = labels, aes(x = xposition, y = yposition, label = label),
                      size=4, angle=90, vjust=-0.4, hjust=0)
        
        ggsave( plot_file, q, width = 6, height = 5 ) 
        print( paste("Plot saved in ",plot_file) )
        
        
        # Frequency plot of the 99th percentile
        plot_file <- paste(save_folder,"frequency_99th_percentile.eps",sep="/")
        
        mean <- mean(percentiles$percentile_99, na.rm=TRUE)
        labels <- data.frame(xposition=c(mean), yposition=labelposition,label="mean" )
        q <- ggplot(percentiles, aes(x=percentile_99)) +
            geom_histogram(aes(y=..count../sum(..count..)),binwidth = 10   )+
            ylab("frequency") + xlab("99th percentile of aggregated queueing delay (ms)") +
            ylim(0, ybound)+
            scale_x_continuous(breaks = round(seq(0, 1000, by = 100),1), 
                               limits=c(0, 1000) )+
            geom_vline(aes(xintercept=mean ), linetype="dotted") +
            geom_text(data = labels, aes(x = xposition, y = yposition, label = label),
                      size=4, angle=90, vjust=-0.4, hjust=0)
        
        ggsave( plot_file, q, width = 6, height = 5 ) 
        print( paste("Plot saved in ",plot_file) )
        
        
    },
             warning=function(w){handle_warning(w,"build_frequency_plots(..)")},
             error=function(e){handle_error(e,"build_frequency_plots(..)")}
    )
}

# Build the point_df unifying all the point dataframes of the single
# tracks (each of which was obtained with get_point(windows), where windows
# are the windows of a single tracks). It saves point_df in the file
# point_savefile
calculate_point_df_useless <- function(filelist)
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
        pointff <- ffdfappend( pointff, pointff_, adjustvmode=T)
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
                    merge( outgoing_windows_1, class_assoc, 
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

plot_percentage_bar <- function()
{
    tryCatch( {
        plot_file <- paste(save_folder,"range_portions.eps",sep="/")
        
        print("Loading outgoing_windows_ff")
        # (windows_ff has been created by build_outgoing_windows_df() )
        ffload(file=window_savefile, overwrite=TRUE)
        # Now, the variable outgoing_windows_ff is available
        
        idx <- ffwhich(outgoing_windows_ff, !is.na(windowed_qd) )
        outgoing_windows_ff_clean <-outgoing_windows_ff[idx,c("windowed_qd","class")]
        outgoing_windowed_qd <- as.data.frame(outgoing_windows_ff_clean)
        remove(outgoing_windows_ff)
        remove(outgoing_windows_ff_clean)
        remove(idx)
        
        range_levels <- c("LOW","MID","HIG")
        
        outgoing_windowed_qd$range = 
            ifelse( outgoing_windowed_qd$windowed_qd >=1000,
                    factor("HIG", levels=range_levels, labels=range_levels), 
                    ifelse(outgoing_windowed_qd$windowed_qd <100, 
                           factor("LOW", levels=range_levels, labels=range_levels), 
                           factor("MID", levels=range_levels, labels=range_levels) )   )
        
        # Inpired by https://sites.google.com/site/r4statistics/example-programs/graphics-ggplot2
        # Workaround in case of probmems:
        # https://github.com/hadley/ggplot2/issues/785
        q <- ggplot(outgoing_windowed_qd, 
                    aes(class, fill=factor(range) ) )+
               geom_bar(position="fill")
        ggsave( plot_file, q, width = 6, height = 6 ) 
        print( paste("Plot saved in ",plot_file) )
    },
              warning = function(w){handle_warning(w,"plot_percentage_bar(..)")},
              error = function(e){handle_error(e,"plot_percentage_bar(..)")}
    )
    
    # Preallocate a vector with the same elements as the rows of outgoing_windowed_qd
    #   see: http://stackoverflow.com/a/3414062
#     range_ <- rep(NA, dim(outgoing_windowed_qd)[1])
#     outgoing_windowed_qd$range <- range_
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
#         filtered_outgoing_windows <- filtered_outgoing_windows[ 
#             filtered_outgoing_windows$class!="P2P" & 
#                 filtered_outgoing_windows$class!="OTHER",]
        
        q <- qplot( class, data=filtered_outgoing_windows, geom="bar")
        q + opts(axis.text.x=theme_text(angle=-90))
        plot_file <- paste(save_folder,"freq_MID.linear.eps",sep="/")
        
        ggsave( plot_file, q, width = 6, height = 4 ) 
        print( paste("Plot saved in ",plot_file) )
        
        #### Interval [1000,+infty[
        idx <- ffwhich(outgoing_windows_ff, !is.na(windowed_qd) &
                           windowed_qd >= 1000)
        if( is.null(idx) ) {
            idx <- as.numeric( array( dim=c(0) ) )
        }
        filtered_outgoing_windows <- as.data.frame( outgoing_windows_ff[idx,] )
#         filtered_outgoing_windows <- filtered_outgoing_windows[ 
#             filtered_outgoing_windows$class!="P2P" & 
#                 filtered_outgoing_windows$class!="OTHER",]
#         
        q <- qplot( class, data=filtered_outgoing_windows, geom="bar")
        q + opts(axis.text.x=theme_text(angle=-90))
        plot_file <- paste(save_folder,"freq_HIGH.linear.eps",sep="/")
        ggsave( plot_file, q, width = 6, height = 4 ) 
        print( paste("Plot saved in ",plot_file) )
        
        #### Interval [0,100[
        idx <- ffwhich(outgoing_windows_ff, !is.na(windowed_qd) &
                           windowed_qd < 100)
        if( is.null(idx) ) {
            idx <- as.numeric( array( dim=c(0) ) )
        }
        filtered_outgoing_windows <- as.data.frame( outgoing_windows_ff[idx,] )
#         filtered_outgoing_windows <- filtered_outgoing_windows[ 
#             filtered_outgoing_windows$class!="P2P" & 
#                 filtered_outgoing_windows$class!="OTHER",]
#         
        q <- qplot( class, data=filtered_outgoing_windows, geom="bar")
        q + opts(axis.text.x=theme_text(angle=-90))
        plot_file <- paste(save_folder,"freq_LOW.linear.eps",sep="/")
        ggsave( plot_file, q, width = 6, height = 4 ) 
        print( paste("Plot saved in ",plot_file) )
        
    },
             warning = function(w){
                 handle_warning(w,"plot_class_distinguished_frequency_plots()")},
             error = function(e){
                 handle_error(e,"plot_class_distinguished_frequency_plots()") }
    )
}

get_class_spread_over_qd_category <- function(){
    tryCatch({
        ffload(file=window_savefile, overwrite=TRUE)
        
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

build_quantile_time_evolution <- function()
{
    tryCatch({
        print("Loading outgoing_windows_ff")
        ffload(file=window_savefile, overwrite=TRUE)
        # Now, the variable outgoing_windows_ff is available
        
        ## Extract time window
        step = 2 #(minutes)
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
            
            
            left_edge <- left_edge+step*60
            iteration <- iteration+1
            
            if(left_edge > right_edge){
                break
            }
        }
        quantiles_df <- data.frame(quantiles)
        quantiles_df <- na.omit(quantiles_df)
        write.table(quantiles_df, file=quantile_evolution_savefile)
        print(paste("quantile evolution saved in ",quantile_evolution_savefile) )
    },
             warning = function(w){handle_warning(w, "build_quantile_time_evolution(..)")},
             error = function(e){handle_error(e, "build_quantile_time_evolution(..)")}
    )
}

plot_quantile_time_evolution <- function()
{
    tryCatch({
        plot_file <- paste(save_folder,"quantile_evolution.eps",sep="/")
        
        quantiles_df<-read.table(quantile_evolution_savefile)
        #Inspired by: http://stackoverflow.com/a/4877936/2110769
        quantiles_df <- melt( quantiles_df, id="left_edge", variable_name = 'quantiles')
        q <- ggplot(quantiles_df, aes(left_edge,value)) +geom_line(aes(colour = quantiles) )+
            ylab("aggregated queueing delay (ms)") + xlab("time")
        ggsave( plot_file, q, width = 10, height = 5 ) 
        print(paste("plot saved in ",plot_file) )
    },
             warning = function(w){handle_warning(w, "plot_quantile_time_evolution(..)")},
             error = function(e){handle_error(e, "plot_quantile_time_evolution(..)")}
    )
    
}

# I had to write this function because of a bug on the standard ffdfappen function in ffbase
# when there are different factor levels in ffdf1 and ffdf2
influence_point_append <- function(ffdf1, ffdf2)
{
    tryCatch({
        writeLines("\n\n\n")
        print("ffdf1 vedi che e'")
        print(ffdf1)
        print("nrow( ffdf1 )")
        print(nrow( ffdf1 ))
        
        if( nrow( ffdf1 ) == 0 
            # | is.na( ffdf1$influencing_class[1] )
            ){
            return(ffdf2)
        }
        if( nrow( ffdf2 ) == 0 
            # | is.na( ffdf2$influencing_class[1] ) 
            ){
            return(ffdf1)
        }
        
        ####### SEVERE DEBUG: begin
        if( is.na( ffdf1$influencing_class[1] ) ){
            print("ffd1")
            print(ffdf1)
            stop("NA in edge, ipaddr, proto, class are not allowed")
        }
        if( is.na( ffdf2$influencing_class[1] ) ){
            print("ffd2")
            print(ffdf2)
            stop("NA in edge, ipaddr, proto, class are not allowed")
        }
        ####### SEVERE DEBUG: end
        
        influencing_class <- ffappend( ffdf1$influencing_class, ffdf2$influencing_class)
        ffdf1$influencing_class <- NULL
        ffdf2$influencing_class <- NULL
        union <- ffdfappend(ffdf1, ffdf2)
        union$influencing_class <- influencing_class
        return(union)
    },
             warning = function(w){handle_warning(w, "influence_point_append(..)")},
             error = function(e){handle_error(e, "influence_point_append(..)")}
    )
}


# Return the rows in dataframe1 and dataframe2 that are not in both dataframes
# inspired by http://stackoverflow.com/a/10907485/2110769
difference <- function(dataframe1, dataframe2)
{
    tryCatch({
        if( dim(dataframe1)[1]==1 & is.na(dataframe1[1, c('edge')]) ){
            # dataframe1 is empty and the difference is exactly dataframe2
            return(dataframe2)
        }
        if( dim(dataframe2)[1]==1 & is.na(dataframe2[1, c('edge')]) ){
            # dataframe2 is empty and the difference is exactly dataframe1
            return(dataframe1)
        }
        
        union <- rbind(dataframe1, dataframe2)
        
        # We use the projection to extrapolate the indexes of the rows that will fall
        # in the result, in order to let the duplicated(..) function work only on few
        # columns in order to reduce the computational load
        union_projection <- subset(union, select=c('edge', 'ipaddr', 'port') )
        
        difference_idx <- 
            ffwhich(union_projection, 
                    !duplicated(x=as.data.frame(union_projection), fromLast = FALSE) & 
                        !duplicated(x=as.data.frame(union_projection), fromLast = TRUE) )
       
        difference_df <- union[difference_idx,]
        
        return(difference_df)
    },
             warning = function(w){handle_warning(w, "difference(..)")},
             error = function(e){handle_error(e, "difference(..)")}
    )
}

merge_large_dataframes <- function(dataframe1, dataframe2)
{
    tryCatch({
        ####### SEVERE DEBUG: begin
        idx <- ffwhich( dataframe1, edge==0 )
        if( !is.null( idx ) ){
            print("idx of 0 edge windowed_qd")
            print(idx)
            stop("there are 0 edges in dataframe1 It is not allowed")
        }
        
        idx <- ffwhich( dataframe2, edge==0 )
        if( !is.null( idx ) ){
            print("idx of 0 edge windowed_qd")
            print(idx)
            stop("there are 0 edges in dataframe2 It is not allowed")
        }
        ####### SEVERE DEBUG: end
        
        step = 5 #(minutes)
        left_edge <- min(dataframe1[,c('edge')] )
        right_edge <- max(dataframe1[,c('edge')] )
        print(paste( "Left edge: ", left_edge, "; right edge:", right_edge) )
        
        merged <- NULL
        iteration <- 1
        repeat
        {
            writeLines("\n\n\n")
            print( paste("Calculating the merge from ", left_edge,"to", left_edge+step*60) )
            extracted1 <- as.data.frame(
                extract_time_window( dataframe1, left_edge, step ) )
            extracted2 <- as.data.frame(
                extract_time_window( dataframe2, left_edge, step ) )
            
            print( "Number of windows extracted" )
            print(length(extracted1[,1]))
            
            ####### SEVERE DEBUG: begin
            if( dim(extracted1)[1] != dim(extracted2)[1] ){
                stop("I would expect the 2 extracted tables be of the same length")
            }
            
            extracted_not_valid <- subset( extracted1, edge==0  )
            if( !is.null( extracted_not_valid ) & 
                    dim(extracted_not_valid)[1] !=0 ){
                print("extracted1 has 0-edge windowed_qd")
                print(extracted_not_valid)
                stop("there are 0 edges in extracted1. It is not allowed")
            }
            
            extracted_not_valid <- subset( extracted2, edge==0  )
            if( !is.null( extracted_not_valid ) & 
                    dim(extracted_not_valid)[1] !=0 ){
                print("extracted2 has 0-edge windowed_qd. It is")
                print(head(extracted_not_valid) )
                
                print("extracted1 is")
                extracted_not_valid <- subset( extracted1, edge==0  )
                print(head(extracted_not_valid) )
                
                print("colnames for extracted1 and extracted2 are")
                colnames(extracted1)
                colnames(extracted2)
                
                stop("there are 0 edges in extracted2. It is not allowed")
            }
            
            print( "SEVERE DEBUG 1 PASSED" )
            ####### SEVERE DEBUG: end
            
            print("Prima di merge")
            merged_not_ff <- merge(x=extracted1, y=extracted2, all.x=FALSE, all.y=FALSE,
                                   by.x=c('edge', 'ipaddr'), by.y=c('edge', 'ipaddr') )
            print("Dopo merge")
            ####### SEVERE DEBUG: begin
            merged_not_ff_not_valid <- subset( merged_not_ff, edge==0  )
            if( !is.null( merged_not_ff_not_valid ) & 
                    dim(merged_not_ff_not_valid)[1] !=0 ){
                print("merged_not_ff_not_valid")
                print(merged_not_ff_not_valid)
                stop("there are 0 edges in merged_not_ff It is not allowed")
            }
            
            merged_ <- as.ffdf( merged_not_ff )
            idx <- ffwhich( merged_, edge==0 )
            if( !is.null( idx ) ){
                writeLines("\n\n\n\niteration")
                print(iteration)
                writeLines("0-edge rows in merged_")
                print(merged_[idx,])
                stop("there are 0 edges in merged_. It is not allowed. ")
            }
            ####### SEVERE DEBUG: end
            
            
            if(iteration ==1){
                merged <- as.ffdf( merged_not_ff )
            }else{
                merged_ <- as.ffdf( merged_not_ff )
                
                ####### SEVERE DEBUG: begin
                idx <- ffwhich( merged, edge==0 )
                if( !is.null( idx ) ){
                    writeLines("\n\n\n\niteration")
                    print(iteration)
                    writeLines("BEFORE MERGING: 0-edge rows in merged")
                    print(merged[idx,])
                    stop("there are 0 edges in merged. It is not allowed. merged_ is ok. So the problem is wqith ffdfappend")
                }

                idx <- ffwhich( merged, edge==0 )
                if( !is.null( idx ) ){
                    writeLines("\n\n\n\nAFTER LOADING: 0-edge rows in merged")
                    print(merged[idx,])
                    stop("there are 0 edges in merged. It is not allowed")
                }
                ####### SEVERE DEBUG: end
                
                merged <- rbind(merged, merged_)
            }
            
            ####### SEVERE DEBUG: begin
            idx <- ffwhich( merged, edge==0 )
            if( !is.null( idx ) ){
                writeLines("\n\n\n\niteration")
                print(iteration)
                writeLines("JUST CALCULATED: 0-edge rows in merged")
                print(merged[idx,])
                stop("there are 0 edges in merged. It is not allowed. merged_ is ok. So the problem is wqith ffdfappend")
            }
            ####### SEVERE DEBUG: end
            
            
            # Now, the variable merged is available
            print("dim of merged is")
            print( dim( merged ) )
            
            left_edge <- left_edge+step*60
            iteration <- iteration+1
            
            if(left_edge > right_edge){
                break
            }
        }
        
        ffsave(merged, file=merged_savefile)
        print( paste( "merged is saved in ", merged_savefile) )
        
        return(merged)
    },
             warning = function(w){handle_warning(w, "merge_large_dataframes(..)")},
             error = function(e){handle_error(e, "merge_large_dataframes(..)")}
    )
    
    
}

# It is a wrapper for merge_large_dataframes(..)
build_merged <- function()
{
    tryCatch({
        print("Loading outgoing_windows_ff")
        ffload(file=window_savefile, overwrite=TRUE)
        # Now, the variable outgoing_windows_ff is available
        print("outgoing_windows_ff is")
        print(outgoing_windows_ff)
        
        # ANNULLATA: idx <- ffwhich(outgoing_windows_ff, !is.na(windowed_qd) )
        # ANNULLATA: outgoing_windows_ff_clean <- outgoing_windows_ff[idx, ]
        
        # I want to associate every windowed_qd to all the protocols that have coexisted 
        # with it. In order to do that, I do an exact copy of outgoing_windows_ff and
        # merge the to copy (as an SQL join)
        outgoing_windows_ff_1 <- ffdf(edge = outgoing_windows_ff$edge, 
                                      ipaddr = outgoing_windows_ff$ipaddr,
                                      influencing_port = outgoing_windows_ff$port,
                                      influencing_proto = outgoing_windows_ff$proto,
                                      influencing_class = outgoing_windows_ff$class)
        
        print("Merging outgoing_windows_ff with itself ...")
        merged <- merge_large_dataframes(outgoing_windows_ff, outgoing_windows_ff_1)
        print("Merge complete")
    },
             warning = function(w){handle_warning(w, "build_merged(..)")},
             error = function(e){handle_error(e, "build_merged(..)")}
    )  
}

# Dependencies: 
# - outgoing_windows_ff (obtained with build_outgoing_windows_df(..) )
# - merged (obtained with build_merged(..) )
get_proto_influence <- function()
{
    tryCatch({
        print("get_proto_influence(..) running ...")
        
        # When analyzing a class of traffic, random_samples will be chosen among
        # windowed_qd that are influenced by that class, and random_samples will be
        # chosen among windowed_qd that are not influenced
        random_samples <- 1000
        
        sampling_activities <- 7
        
        # A point influenced by a class C is a windowed queueing delay
        # that has coexisted with class C, i.e., in the second which the
        # windowed queueing delay is calculated in, there has existed a flow
        # of protocol C.
        # The inflenced_point dataframe attaches every windowed queueing delay with all
        # the classes that influence it (if any)
        
        print("Loading outgoing_windows_ff")
        ffload(file=window_savefile, overwrite=TRUE)
        # Now, the variable outgoing_windows_ff is available
        print("outgoing_windows_ff is")
        print(outgoing_windows_ff)
        
        influenced_point_colnames <- 
            c('edge', 'ipaddr', 'port', 'protocol', 'windowed_qd', 'influencing_class')
        
        ####### SEVERE DEBUG: begin
        rownames <- row.names(outgoing_windows_ff)
        if( !is.null( rownames ) ) {
            print( "row_names of outgoing_windows_ff are" )
            print(rownames)
            stop( "rownames must be NULL." )
        }    
        ####### SEVERE DEBUG: end
        
        print("Loading merged and printing it")
        ffload(file=merged_savefile, overwrite=TRUE)
        # Now the variable merged is loaded
        print(merged)
        
        # Having done the merge, there are rows merged with themselves. We want to
        # eliminate these association, otherwise I would assert that each windowed queueing
        # delay is influenced by itself (and it's nonsense)
        idx <- ffwhich(merged, port != influencing_port )
        influence <- merged[idx,]
        
        classes <- class_assoc$class[ !duplicated(class_assoc$class) ]
        influence_point <- NULL
        proto_influence_table <- NULL
        iteration <- 1
        
        repeat{
            writeLines("\n\n\n\n\n\n\n\n#############\n")
            traffic_class <- classes[iteration]
            
            # I will label with the following string to all the outgoing windowed queueing delay
            # that are not influenced by this traffic_class
            filling_string <- factor( paste(traffic_class,"NO",sep="_") )
            
            ####### SEVERE DEBUG: begin
            if( iteration > length( classes ) ){
                stop("iteration=", iteration,"while length( classes )=",length( classes ))
            }
            
            if( is.na( traffic_class ) ){
                print("traffic_class is")
                print(traffic_class)
                stop( paste("iteration=", iteration, ": Traffic class cannot be NA") )
            }
            ####### SEVERE DEBUG: end
            
            print("Analyzing the influence of class ")
            print(traffic_class)
            
            # I want to extract all the windowed_qd influenced by traffic_class
            bool_vector <- as.character(influence$influencing_class)==as.character(traffic_class)
            idx_influenced <- ffwhich(influence, bool_vector )
            
            influenced_by_class <- NULL
            if(!is.null(idx_influenced) ){
                influenced_by_class_verbose <- influence[idx_influenced,]
                
                # Get rid of all the useless columns
                influenced_by_class <- subset( influenced_by_class_verbose, 
                                               select=influenced_point_colnames )
                
                # Now, I want to find all the windowed queueing delays that are NOT influenced
                # by traffic class. In order to do this, I want to substract the influenced
                # windowed_qd from the set of all the outgoing windowed_qd (this set is represented
                # by outgoing_windows_ff). It is technically required that the influenced
                # windowed_qds that I want to substract are in the same format (i.e. with the same
                # columns) of outgoing_windows. It is why I need to operate the following projection
                influenced_by_class_projected_on_outgoing_windows_cols <- 
                    subset(influenced_by_class_verbose, select=colnames(outgoing_windows_ff) )
                
                non_influenced_by_class_ <-
                    difference( outgoing_windows_ff , 
                                influenced_by_class_projected_on_outgoing_windows_cols )
                
                # Now, I want to add to give to non_influenced_by_class the same format of 
                # influenced_by_class (because later I want to unify them). I need to add the
                # influencing_class column. I want that all values in this column are
                # filling_string
                
                
            }else{
                # This class does not influence any windowed_qd
                non_influenced_by_class_ <- outgoing_windows_ff
                
            }
          
            # Now I add a column filled with the filling_string
            influencing_class <- ff(rep(filling_string, 
                                        length.out=dim(non_influenced_by_class_)[1] ) )
            non_influenced_by_class_$influencing_class <- influencing_class
            
            # I don't care anymore the actual class of the windowed_qd
            non_influenced_by_class_$class <- NULL
            non_influenced_by_class <- non_influenced_by_class_
            
            #Now, we have influenced_by_class and non_influenced_by_class
            
            
            writeLines("\n\n\ntraffic_class")
            print(traffic_class)
            print("influenced_by_class")
            print(nrow(influenced_by_class) )
            print("non_influenced_by_class")
            print(nrow(non_influenced_by_class) )
            
            how_many <- min(random_samples, nrow(influenced_by_class), 
                            nrow(non_influenced_by_class) )
            
            if(how_many == 0){
                print( paste("how_many=", how_many ) )
            }else{
                for(i in 1:sampling_activities) {
                    print( paste( "sampling activity", i) )
                    idx <- sample(nrow(influenced_by_class), how_many)
                    selected_influenced_by_class <- as.data.frame(influenced_by_class[idx,] )
                    print("selected_influenced_by_class found")
                    
                    idx <- sample(nrow(non_influenced_by_class), how_many)
                    selected_non_influenced_by_class <- 
                        as.data.frame(non_influenced_by_class[idx,] )
                    print("selected_non_influenced_by_class found")
                    
                    print("class of windowed_qd")
                    print( class( selected_influenced_by_class$windowed_qd ) )
                    print( class( selected_non_influenced_by_class$windowed_qd ) )
                    
                    influenced_by_class_quantiles <- 
                        quantile(selected_influenced_by_class$windowed_qd,
                                 c(0.50, .90, .95, .99) )
                    print("quantiles of the influenced windowed_qds")
                    print(influenced_by_class_quantiles)
                    
                    non_influenced_by_class_quantiles <- 
                        quantile(selected_influenced_by_class$windowed_qd,
                                 c(0.50, .90, .95, .99) )
                    print("quantiles of the non_influenced windowed_qds")
                    print(non_influenced_by_class_quantiles)
                    
                    print("influenced_by_class_quantiles[c(.50)]" )
                    print( class(influenced_by_class_quantiles[c(.50)]) )
                    print(influenced_by_class_quantiles[c(.50)] )
                    
                    proto_influence_table_ <- 
                        data.frame(class_of_traffic=traffic_class,
                                   influenced_rows=nrow(influenced_by_class),
                                   non_influenced_rows=nrow(non_influenced_by_class),
                                   influenced_quant_50=influenced_by_class_quantiles[c(.50)],
                                   non_influenced_quant_50=non_influenced_by_class_quantiles[c(.50)],
                                   influenced_quant_90=influenced_by_class_quantiles[c(.90)],
                                   non_influenced_quant_90=non_influenced_by_class_quantiles[c(.90)],
                                   influenced_quant_95=influenced_by_class_quantiles[c(.95)],
                                   non_influenced_quant_95=non_influenced_by_class_quantiles[c(.95)],
                                   influenced_quant_99=influenced_by_class_quantiles[c(.99)],
                                   non_influenced_quant_99=non_influenced_by_class_quantiles[c(.99)]
                                   )
                    
                    if( is.null(proto_influence_table) ){
                        # This is the first row that we add to the table
                        proto_influence_table <- proto_influence_table_
                    }else{
                        proto_influence_table <- rbind(proto_influence_table, proto_influence_table_)
                    }
                    print("Now proto_influence_table is")
                    print(proto_influence_table)
                }# end of i-th sampling activity
            }
            
            
            
            # Activate only if you want to build influence_point
            if(FALSE){
                if( !is.null(idx_influenced) ){
                    # Doing as follows does not work. Why?
                    # see https://stat.ethz.ch/pipermail/r-help/2007-January/124277.html
                    #             influence_point_ <- 
                    #                 ifelse( nrow(influenced_by_class)==0,
                    #                         non_influenced_by_class_,
                    #                         influence_point_append( influenced_by_class, non_influenced_by_class_)
                    #                 )
                    #             
                    influence_point_ <- 
                        influence_point_append( influenced_by_class, non_influenced_by_class_)
                    
                }else{
                    # This class does not influence any windowed_qd
                    influence_point_ <- non_influenced_by_class_
                }
                
                #              influence_point_ <- NULL
                #              if( nrow(influenced_by_class) == 0 ){
                #                  influence_point_ <- non_influenced_by_class_
                #              }else{
                #                  influence_point_ <- 
                #                      influence_point_append( influenced_by_class, non_influenced_by_class_)
                #              }}
                
                ####### SEVERE DEBUG: begin
                if( !is.ffdf(influence_point_) ){
                    print("class of influence_point_ is")
                    print( class(influence_point_) )
                    print("influence_point_ is")
                    print( influence_point_) 
                    stop("influence_point_ is not an ffdf. It's nonsense")
                }
                
                if( is.null(non_influenced_by_class_) ){
                    print("non_influenced_by_class_ is")
                    print(non_influenced_by_class_)
                    stop("non_influenced_by_class_ is NULL. It's very strange")
                }
                
                if( is.null( dim(non_influenced_by_class_) ) ){
                    print("class of non_influenced_by_class_ is")
                    print( class(non_influenced_by_class_) )
                    print("non_influenced_by_class_ is")
                    print(non_influenced_by_class_)
                    stop("dim of non_influenced_by_class_ is NULL. It's nonsense")
                }
                
                if( is.null(influence_point_) ){
                    print("influence_point_ is")
                    print(influence_point_)
                    stop("influence_point_ is NULL. It's nonsense")
                }
                
                if( is.null( dim(influence_point_) ) ){
                    print("class of influence_point_ is")
                    print( class(influence_point_) )
                    print("influence_point_ is")
                    print(influence_point_)
                    stop("dim of influence_point_ is NULL. It's nonsense")
                }
                
                if( is.na(influence_point_[1,c('edge') ] ) ){
                    print("influence_point_ is")
                    print(influence_point_)
                    stop("influence_point_ has a null-edge row. It's nonsense")
                }
                ####### SEVERE DEBUG: end
                
                if( iteration==1 ){
                    influence_point <- influence_point_
                }else{
                    influence_point <- influence_point_append(influence_point, influence_point_)
                }
                
            }
            
            
            
#             if(iteration==1){
#                 influence_point <- influence_point_
#             }else{
#                 
#                 influence_point <- ffdfappend(influence_point, influence_point_,
#                                               recode=TRUE, adjustvmode=TRUE)
#                 print("Dentro else dopo di ffdfappend di influence point")
#             }
            
            iteration <- iteration +1
            if(iteration > length( classes ) ){
                break
            }
        }
        
        write.table(proto_influence_table, file=proto_influence_savefile)
        print( paste( "proto_influence_table is saved in ", proto_influence_savefile ) )
        
        if(FALSE){
            print("Now influence_point is")
            print(as.data.frame(influence_point) )
            return(influence_point)
        }
    },
             warning = function(w){handle_warning(w, "get_proto_influence(..)")},
             error = function(e){handle_error(e, "get_proto_influence(..)")}
    )   
}

build_influence_point_df_useless <- function()
{
    print("Loading outgoing_windows_ff")
    ffload(file=window_savefile, overwrite=TRUE)
    # Now, the variable outgoing_windows_ff is available
    
    ####### SEVERE DEBUG: begin
    idx <- ffwhich(outgoing_windows_ff, edge==0 | is.na(ipaddr))
    len <- length( idx )
    if( len != 0 ){
        stop(paste( "There are",len,"invalid values in outgoing_windows") )
    }
    ####### SEVERE DEBUG: end
    
    print("Building influence_point")
    
    idx<-fforder(outgoing_windows_ff$edge, outgoing_windows_ff$ipaddr)
    outgoing_windows_ff_ord <- outgoing_windows_ff[idx ,]
    outgoing_windows_ff_ord_subsetted <- outgoing_windows_ff_ord
    row.names(outgoing_windows_ff_ord_subsetted) <- NULL
    
    influence_point <- get_proto_influence( outgoing_windows_ff_ord_subsetted )
    ffsave(influence_point, file=influence_point_savefile)
    
    print( paste( "influence_point is saved in ", influence_point_savefile) )
    
    print("Trying to load influence_point")
    ffload(file=influence_point_savefile, overwrite=TRUE)
    # Now, the variable influence_point_savefile is available
    print("dim of influence_point is")
    print( dim( influence_point ) )
}

tryCatch({
    print( paste("log file in ", r_logfile) )
    build_merged()
},
         warning = function(w){handle_warning(w, ",main execution")},
         error = function(e){handle_error(e, ",main execution")}
)
