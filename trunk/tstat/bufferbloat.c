//<aa>

#include "tstat.h"
#include "bufferbloat.h"

#ifdef BUFFERBLOAT_ANALYSIS

#if defined(BUFFERBLOAT_ANALYSIS) && defined(SEVERE_DEBUG) && defined(ONE_FLOW_ONLY)
static unsigned long long latest_window_edge[2][3]; //first index is in {TCP,LEDBAT}, 
					 //second index is in {ACK_TRIG,DATA_TRIG, DONT_CARE}
					 //for ledbat, alway set second index = DONT_CARE
#endif


extern FILE *fp_tcp_windowed_qd_acktrig_logc, *fp_tcp_windowed_qd_datatrig_logc,
	*fp_ledbat_windowed_qd_logc;

#if defined(SEVERE_DEBUG) && defined(ONE_FLOW_ONLY)
extern unsigned long f_TCP_count;
#endif


#ifdef FORCE_CALL_INLINING
extern inline
#endif
delay_t get_queueing_delay(const utp_stat* bufferbloat_stat_p)
{	//milliseconds
	delay_t filtered_gross_delay = bufferbloat_stat_p->cur_gross_delay_hist[0];

	#ifdef FILTERING
		//Find the minimum gross delay over cur_gross_delay_hist.
		int i=1;
		while ( i<CUR_DELAY_SIZE ){
			if (	( (	bufferbloat_stat_p->cur_gross_delay_hist[i]< 
					filtered_gross_delay ) 
				&&  (bufferbloat_stat_p->cur_gross_delay_hist[i]>0)	
				)	
					|| 
				filtered_gross_delay == 0
			)
				filtered_gross_delay = bufferbloat_stat_p->cur_gross_delay_hist[i];
	
			i++;
		}
	#else //FILTERING not defined
		//only the first element of cur_gross_delay_hist is used
		#ifdef SEVERE_DEBUG
		int i=1;
		while ( i<CUR_DELAY_SIZE ){
			if (bufferbloat_stat_p->cur_gross_delay_hist[i] != 0){
				printf("line %d:ERROR in get_queueing_delay",__LINE__);
				exit(547921);
			}
			i++;
		}
		#endif
	#endif //of FILTERING
	
	return filtered_gross_delay - bufferbloat_stat_p->delay_base;
} //get_queueing_delay: end
//</aa>

/* <aa>I don't want to use this function</aa>
// compare if lhs is less than rhs, taking wrapping
// into account. if lhs is close to UINT_MAX and rhs
// is close to 0, lhs is assumed to have wrapped and
// considered smaller
int wrapping_compare_less(u_int32_t lhs, u_int32_t rhs)
{
	//<aa>See http://stackoverflow.com/a/7221449 or 
	// http://bytes.com/topic/c/answers/811289-subtracting-unsigned-entities
	// for the behavior in case of subtraction between unsigned integers</aa>

	// distance walking from lhs to rhs, downwards
	const u_int32_t dist_down = lhs - rhs;
	//<aa> if lhs<rhs, dist_down = MAX - (rhs-lhs)</aa>

	// distance walking from lhs to rhs, upwards
	const u_int32_t dist_up = rhs - lhs;
	//<aa> if rhs<lhs, dist_down = MAX - (lhs-rhs)</aa>

	// if the distance walking up is shorter, lhs
	// is less than rhs. If the distance walking down
	// is shorter, then rhs is less than lhs
	return dist_up < dist_down;
}
*/


//<aa>TODO: Find a more efficient way to compute the minimum</aa>
#ifdef FORCE_CALL_INLINING
extern inline
#endif
delay_t min_delay_base(const utp_stat* bufferbloat_stat_p){
	#if defined(SEVERE_DEBUG) && !defined(FILTERING)
	printf("line %d:ERROR min_delay_base should not be called if FILTERING is disabled\n",__LINE__); 
	exit(112);
	#endif

	delay_t min = bufferbloat_stat_p->delay_base_hist[0]; //milliseconds
	int i=1;
	while ( i<DELAY_BASE_HISTORY ){
		if ( bufferbloat_stat_p->delay_base_hist[i] < min ) 
			min=bufferbloat_stat_p->delay_base_hist[i];
		i++;
	}	
	return min;
}

//<aa>
#ifdef FORCE_CALL_INLINING
extern inline
#endif
void update_gross_delay_related_stuff(delay_t gross_delay,utp_stat* bufferbloat_stat_p){
	#ifdef SEVERE_DEBUG
	if (gross_delay==0){
		fprintf(stderr,"bufferbloat.c %d: WARNING: gross delay = 0\n",__LINE__);
	}

	#ifndef FILTERING
		//We do not use the delay_base_hist
		int j=0;
		for( ; j<DELAY_BASE_HISTORY; j++){
			if (bufferbloat_stat_p->delay_base_hist[j]!=0){
				printf("line %d:ERROR in update_gross_delay_related_stuff\n",__LINE__);
				exit(74747);
			}
		}

		//We use only the first element of cur_gross_delay_hist
		if(bufferbloat_stat_p->cur_delay_idx != 0){
			printf("line %d:ERROR in update_gross_delay_related_stuff\n",__LINE__);
			exit(74748);
		}
		for(j=1 ; j<DELAY_BASE_HISTORY; j++){
			if(bufferbloat_stat_p->cur_gross_delay_hist[j] != 0){
				printf("line %d:ERROR in update_gross_delay_related_stuff\n",__LINE__);
				exit(74749);
			}	
		}
	#endif //of FILTERING
	#endif //of SEVERE_DEBUG

	#ifdef FILTERING
		int j=0;
		while ( j<DELAY_BASE_HISTORY ){
			if (bufferbloat_stat_p->delay_base_hist[j]==0) 
				bufferbloat_stat_p->delay_base_hist[j]=gross_delay;
			j++;
			//bufferbloat_stat_p->delay_base=gross_delay;
		}

		if ( 	 elapsed(bufferbloat_stat_p->last_rollover, current_time) > 60e6 ) {
			// <aa>"LEDBAT sender stores BASE_HISTORY separate minima---one each for the
			// last BASE_HISTORY-1 minutes, and one for the running current minute.
			// At the end of the current minute, the window moves---the earliest
			// minimum is dropped and the latest minimum is added."
			// </aa>

			//<aa>It corresponds to the "last_rollover" in the draft</aa>
			bufferbloat_stat_p->last_rollover=current_time;
		
			int i=1; //rollover della lista di base_delay
			while ( i<DELAY_BASE_HISTORY ){
				bufferbloat_stat_p->delay_base_hist[i-1]=bufferbloat_stat_p->delay_base_hist[i];
				i++;
			}
			bufferbloat_stat_p->delay_base_hist[DELAY_BASE_HISTORY-1]=gross_delay;
	
		}else{ //update the tail
			if (	wrapping_compare_less(	gross_delay, 
					bufferbloat_stat_p->delay_base_hist[DELAY_BASE_HISTORY-1])
			)  
				bufferbloat_stat_p->delay_base_hist[DELAY_BASE_HISTORY-1]=gross_delay;
				//<aa>according to the draft, we calculate the one-way delay minima over a
				//one-minute interval</aa>
		}

		bufferbloat_stat_p->delay_base = min_delay_base (bufferbloat_stat_p);

		//<aa>The following two lines correspond to update_current_delay(...) in 
		//section 3.4.2 of [ledbat_draft]</aa>
		// <aa>[ledbat_draft] sec 3.4.2 says that update_current_delay(...)
		// mantains a list of one-way delays, whereas we mantain a list of estimated queueing delays.
		// But we handle this vector in a slightly different way and verified that this does not 
		// affect the queueing delay estimation</aa>

	   	//collect last CUR_DELAY_SIZE queueing delay 
		
		//u_int32_t qd_delay= gross_delay - bufferbloat_stat_p->delay_base;
		//bufferbloat_stat_p->cur_delay_hist[bufferbloat_stat_p->cur_delay_idx]=qd_delay;

		//<aa>TODO: remove this or the update of cur_delay_hist
		bufferbloat_stat_p->cur_gross_delay_hist[bufferbloat_stat_p->cur_delay_idx] = gross_delay;
		//</aa>	

		bufferbloat_stat_p->cur_delay_idx= (bufferbloat_stat_p->cur_delay_idx+1)% CUR_DELAY_SIZE;
	#else //FILTERING not defined
		//Store the last gross_delay
		bufferbloat_stat_p->cur_gross_delay_hist[0] = gross_delay;

		if(	gross_delay < bufferbloat_stat_p->delay_base ||

			bufferbloat_stat_p->delay_base == 0 
			//delay_base never measured before
		)
			bufferbloat_stat_p->delay_base = gross_delay ;
	#endif //of FILTERING
} // end of update_gross_delay_related_stuff(...)
//</aa>

#ifdef SAMPLES_BY_SAMPLES_LOG
#ifdef FORCE_CALL_INLINING
extern inline
#endif
void print_queueing_dly_sample(enum analysis_type an_type,  
	enum bufferbloat_analysis_trigger trig,
	const tcp_pair_addrblock* addr_pair, 	int dir,
	utp_stat* bufferbloat_stat_p, int utp_conn_id,delay_t estimated_qd, 
	const char* type, u_int32_t pkt_size, delay_t last_grossdelay)
{
	#ifdef SEVERE_DEBUG
	if(an_type != LEDBAT && an_type != TCP){
		printf("ERROR in print_queueing_dly_sample, line %d\n",__LINE__); 
		exit(414);
	}

	if(an_type==TCP && trig!=ACK_TRIG 
		#ifdef DATA_TRIGGERED_BUFFERBLOAT_ANALYSIS
		&& trig!=DATA_TRIG
		#endif
	){
		printf("ERROR in print_queueing_dly_sample, line %d: trig vs ledbat\n",
			__LINE__); 
		exit(414);
	}

	if(an_type == LEDBAT && trig != DONT_CARE_TRIG){
		printf("ERROR in print_queueing_dly_sample, line %d: trig vs ledbat\n",
			__LINE__); 
		exit(414);
	}
	#endif

	FILE* fp_qd=NULL;
	switch (an_type){
		case TCP:	if(trig == ACK_TRIG)
						fp_qd = fp_tcp_qd_sample_acktrig_logc;
					#ifdef DATA_TRIGGERED_BUFFERBLOAT_ANALYSIS
					else 
						fp_qd = fp_tcp_qd_sample_datatrig_logc ;
					#endif
					break;

		default:	fp_qd = fp_ledbat_qd_sample_logc; 
				break;
	}

	#ifdef SEVERE_DEBUG
	if (dir!=S2C && dir!=C2S) {
		printf("ERROR: dir (%d) not valid\n",dir); exit(7777);
	}

	if(last_grossdelay < estimated_qd){
		printf("line %d:ERROR in  print_queueing_dly_sample\n",__LINE__);exit(3356);
	}
	#endif

	wfprintf(fp_qd,"%u ",
		(unsigned) current_time.tv_sec				//1. seconds
	);	

	wfprintf (fp_qd, "%s %s ",
      	           HostName (addr_pair->a_address),	//2.ip_addr_1
       	           ServiceName (addr_pair->a_port));	//3.port_1
  	wfprintf (fp_qd, "%s %s ",
       	           HostName (addr_pair->b_address),	//4.ip_addr_2
       	           ServiceName (addr_pair->b_port));	//5.port_2


	wfprintf (fp_qd, "%d ", dir); 		//6.dir
	
	switch(an_type){
		case (LEDBAT):	wfprintf (fp_qd, "%d ", utp_conn_id); 
							//7.conn_id
				break; 

		case (TCP):	wfprintf (fp_qd, "- "); break;
		default:	fprintf(stderr, "ERROR: analysis type not valid\n"); 
				exit(54321);
	}

	wfprintf (fp_qd, "%u %u ",
		bufferbloat_stat_p->delay_base,		//8.delay_base (milliseconds)
		estimated_qd				//9.estimated_qd (milliseconds)
	);

	wfprintf (fp_qd, "- "); 			//10.flowtype
	wfprintf (fp_qd, "%u", pkt_size); 		//11.pkt_size
	wfprintf (fp_qd, DELAY_T_FORMAT_SPECIFIER, last_grossdelay);	//12.last_grossdelay(milliseconds)
	wfprintf (fp_qd, " %s\n", type);	 		//13.type
	fflush(fp_qd);
}
#endif //of SAMPLES_BY_SAMPLES_LOG

const float EWMA_ALPHA = 0.5;

//<aa>TODO: verify if the compiler do the call inlining</aa>
delay_t bufferbloat_analysis(enum analysis_type an_type,
	enum bufferbloat_analysis_trigger trig, const tcp_pair_addrblock* addr_pair, 
	const int dir, utp_stat* bufferbloat_stat, utp_stat* otherdir_bufferbloat_stat, 
	int utp_conn_id, const char* type, u_int32_t pkt_size, delay_t last_grossdelay,
	Bool overfitting_avoided, Bool update_size_info)
{
	delay_t windowed_qd = -1;

	#ifdef SEVERE_DEBUG
	char* an_details;
	if(an_type == TCP && trig == ACK_TRIG) 
		an_details = "TCP-ACK_TRIG";
	#ifdef DATA_TRIGGERED_BUFFERBLOAT_ANALYSIS
	else if(an_type == TCP && trig == DATA_TRIG) 
		an_details = "TCP-DATA_TRIG";
	#endif
	else if(an_type == LEDBAT) 
		an_details = "LEDBAT";
	else	an_details = "ERROR";
	check_direction_consistency_light(bufferbloat_stat, otherdir_bufferbloat_stat,
		__LINE__);

	if (last_grossdelay==0){
		printf("bufferbloat.c %d: an_details:%s WARNING: gross delay = 0ms\n",
			__LINE__, an_details);
	}
	if (bufferbloat_stat == otherdir_bufferbloat_stat){
		printf("line %d: thisdir_bufferbloat_stat == otherdir_bufferbloat_stat\n",__LINE__); exit(11);
	}
	
	if(	bufferbloat_stat->not_void_windows != 0
		&&
		otherdir_bufferbloat_stat->not_void_windows != 0
	){
			#ifdef SAMPLES_VALIDITY
			if(	bufferbloat_stat->qd_calculation_chances - 
				bufferbloat_stat->qd_calculation_chances_until_last_window <=0 
				&&
				otherdir_bufferbloat_stat->qd_calculation_chances - 
				otherdir_bufferbloat_stat->qd_calculation_chances_until_last_window <=0 
			){
				printf("\nERROR on line %d: 0 qd chances in both directions\n",__LINE__);
				exit(222);
			}
			#else //SAMPLES_VALIDITY is not defined
			if(	bufferbloat_stat->qd_measured_count - 
				bufferbloat_stat->qd_samples_until_last_window <=0 
				&&
				otherdir_bufferbloat_stat->qd_measured_count - 
				otherdir_bufferbloat_stat->qd_samples_until_last_window <=0 
			){
				printf("\nbufferbloat.c %d: ERROR: 0 qd samples in both directions.\
					\nqd_measured_count=%d, qd_samples_until_last_window=%d\n",
					__LINE__, bufferbloat_stat->qd_measured_count, 
					bufferbloat_stat->qd_samples_until_last_window);
				exit(223);
			}
			#endif //of SAMPLES_VALIDITY
	}

	#ifdef ONE_FLOW_ONLY
	if(	latest_window_edge[(int)an_type][(int)trig] != 0
	     && bufferbloat_stat->last_window_edge != 0
	     && (  bufferbloat_stat->last_window_edge < latest_window_edge[(int)an_type][(int)trig]
	         ||otherdir_bufferbloat_stat->last_window_edge < latest_window_edge[(int)an_type][(int)trig]
		)
	) {
		printf("\nERROR in line %d in bufferbloat_analysis, an_details=%s, tcp_flows=%lu\n",
			__LINE__, an_details, f_TCP_count);
		printf("this_bufferbloat_stat->last_window_edge=%u, other_bufferbloat_stat->last_window_edge=%u, latest_window_edge=%u, this_bufferbloat=%p, \n",
			(unsigned)bufferbloat_stat->last_window_edge, 
			(unsigned)otherdir_bufferbloat_stat->last_window_edge,
			(unsigned)latest_window_edge[(int)an_type][(int)trig],
			bufferbloat_stat);
		exit(1274);
	}
	#endif //of ONE_FLOW_ONLY

	delay_t last_window_qd_sum_for_debug = bufferbloat_stat->qd_measured_sum -
				bufferbloat_stat->sample_qd_sum_until_last_window;
	if(	last_window_qd_sum_for_debug <= 0 &&
		bufferbloat_stat->last_unwindowed_qd_sample != 0
	){	printf("\nbufferbloat.c %d: ERROR: last_window_qd_sum_for_debug=%f, last_unwindowed_qd_sample=%f\n",
			__LINE__, (float)last_window_qd_sum_for_debug, 
			(float)bufferbloat_stat->last_unwindowed_qd_sample);
		printf("\nqd_measured_sum=%f, sample_qd_sum_until_last_window=%f\
			not_void_windows=%d, qd_measured_count=%d\n",
			(float)bufferbloat_stat->qd_measured_sum, 
			(float)bufferbloat_stat->sample_qd_sum_until_last_window,
			bufferbloat_stat->not_void_windows, 
			bufferbloat_stat->qd_measured_count);
			
		exit(177746);
	}

	#endif //of SEVERE_DEBUG


	update_gross_delay_related_stuff(last_grossdelay, bufferbloat_stat );//ptcp is thisdir

	//milliseconds
	delay_t estimated_qd = get_queueing_delay((const utp_stat*)bufferbloat_stat ); 

	#ifdef SAMPLES_BY_SAMPLES_LOG
	print_queueing_dly_sample(an_type, trig, addr_pair,
		dir, bufferbloat_stat, 0, estimated_qd, type, pkt_size, 
		last_grossdelay);
	#endif

	/***** UPDATING PACKETS AND BYTES INFO: begin *****/
	//some statistics
	//note: we consider type_utp for type of the packet, not type field in the packet
	bufferbloat_stat->total_pkt++;
	bufferbloat_stat->bytes += pkt_size;

	if ( update_size_info == TRUE)	{
		bufferbloat_stat->data_pktsize_sum += pkt_size;
		
		if (	(bufferbloat_stat->data_pktsize_max == 0) 
		      ||(bufferbloat_stat->data_pktsize_max < pkt_size)
		)
			bufferbloat_stat->data_pktsize_max = pkt_size;

		if (	(bufferbloat_stat->data_pktsize_min == 0) 
		      ||(bufferbloat_stat->data_pktsize_min > pkt_size)
		)
			bufferbloat_stat->data_pktsize_min = pkt_size;
	}
	/***** UPDATING PACKETS AND BYTES INFO: end *****/

	if(	overfitting_avoided == TRUE 
	      ||estimated_qd<120000 //<aa>??? why? </aa>
	){
		#ifdef SEVERE_DEBUG
		check_direction_consistency_light(bufferbloat_stat, otherdir_bufferbloat_stat,
			__LINE__);
		#endif //of SEVERE_DEBUG

		//Before updating the bufferbloat info of this flow, see if a window can be 
		//closed (not including the present pkt)
        windowed_qd = windowed_queueing_delay(an_type, trig, addr_pair, 
			bufferbloat_stat, otherdir_bufferbloat_stat, dir, type,
			utp_conn_id);

		#ifdef SEVERE_DEBUG
		check_direction_consistency_light(bufferbloat_stat, otherdir_bufferbloat_stat,
			__LINE__);
		#endif

		if ( update_size_info==TRUE )
			bufferbloat_stat->last_measured_time_diff = last_grossdelay*1000;
	
		//<aa>Update the max
		if (estimated_qd >= bufferbloat_stat->qd_max_w1)
			bufferbloat_stat->qd_max_w1=estimated_qd;
		
		#ifdef SAMPLES_VALIDITY
		bufferbloat_stat->qd_calculation_chances++;
		#endif

		bufferbloat_stat->qd_measured_count++;
		bufferbloat_stat->qd_measured_sum+= estimated_qd;
		bufferbloat_stat->qd_measured_sum2+= ((estimated_qd)*(estimated_qd));

		#ifdef SEVERE_DEBUG
		bufferbloat_stat->last_unwindowed_qd_sample = estimated_qd;
/*		#ifndef SAMPLES_VALIDITY
		printf("\nbufferbloat.c %d: After incrementing qd_measured_count=%d,\
			qd_measured_count_until_last_window=%d\n",
			__LINE__,  bufferbloat_stat->qd_measured_count, 
			bufferbloat_stat->qd_samples_until_last_window);
		#endif
*/		bufferbloat_stat->gross_dly_measured_sum += last_grossdelay;

		#ifndef FILTERING
		if(	bufferbloat_stat->last_measured_time_diff/1000 != 
			bufferbloat_stat->cur_gross_delay_hist[0]
		){
			printf("line %d:ERROR in bufferbloat_analysis\n",__LINE__);exit(799);
		}
		#endif
		
		check_direction_consistency_light(bufferbloat_stat, otherdir_bufferbloat_stat,
			__LINE__);
		#endif //of SEVERE_DEBUG

		float ewma; //Exponentially-Weighted Moving Average

       	if (bufferbloat_stat->ewma > 0) {
                   ewma = bufferbloat_stat->ewma;
                   bufferbloat_stat->ewma = 
			EWMA_ALPHA * (estimated_qd) + (1-EWMA_ALPHA) * ewma;
		}else
		   bufferbloat_stat->ewma = estimated_qd;
  		       
		if ((bufferbloat_stat->queueing_delay_max < (estimated_qd)))
			bufferbloat_stat->queueing_delay_max= (estimated_qd);

		if ((bufferbloat_stat->queueing_delay_min > (estimated_qd)))
			bufferbloat_stat->queueing_delay_min= (estimated_qd);

		#ifdef SEVERE_DEBUG
		if(	bufferbloat_stat->not_void_windows != 0
			&&
			otherdir_bufferbloat_stat->not_void_windows != 0
		){
			#ifdef SAMPLES_VALIDITY
			if(	bufferbloat_stat->qd_calculation_chances - 
				bufferbloat_stat->qd_calculation_chances_until_last_window <=0 
			){
				printf("\nERROR on line %d: 0 qd chances in both directions\n",__LINE__);
				exit(222);
			}
			#else //SAMPLES_VALIDITY is not defined
			if(	bufferbloat_stat->qd_measured_count - 
				bufferbloat_stat->qd_samples_until_last_window <=0 
			){
				printf("\nbufferbloat.c %d: ERROR: 0 qd samples in both directions.\
					\nqd_measured_count=%d, qd_samples_until_last_window=%d\n",
					__LINE__, bufferbloat_stat->qd_measured_count, 
					bufferbloat_stat->qd_samples_until_last_window);
				exit(223);
			}
			#endif //of SAMPLES_VALIDITY
		}
		check_direction_consistency_light(bufferbloat_stat, otherdir_bufferbloat_stat,
			__LINE__);
		#endif //of SEVERE_DEBUG
	}
	#ifdef SEVERE_DEBUG
	check_direction_consistency_light(bufferbloat_stat, otherdir_bufferbloat_stat,
		__LINE__);

	#ifdef ONLE_FLOW_ONLY
	if(	latest_window_edge[(int)an_type][(int)trig] != 0
	     && (  bufferbloat_stat->last_window_edge < latest_window_edge[(int)an_type][(int)trig]
	         ||otherdir_bufferbloat_stat->last_window_edge < latest_window_edge[(int)an_type][(int)trig]
		)
	) {
		printf("bufferbloat_stat->last_window_edge=%u, other_bufferbloat_stat->last_window_edge=%u, latest_window_edge=%u\n",
			(unsigned)bufferbloat_stat->last_window_edge, 
			(unsigned)otherdir_bufferbloat_stat->last_window_edge,
			(unsigned)latest_window_edge[(int)an_type][(int)trig]);
		printf("\nERROR in line %d in bufferbloat_analysis, an_details=%s\n",
			__LINE__, an_details);
		exit(1274);
	}
	#endif

	//<aa>TODO: If they are always equal, for every analysis (TCP, LEDBAT, 
	//ACKTRIG, DATATRIG), remove one of the two</aa>
	if (bufferbloat_stat->total_pkt != bufferbloat_stat->qd_measured_count){
		printf("\nERROR in line %d in bufferbloat_analysis, an_details=%s\n",
			__LINE__, an_details);
		exit(1275);
	}
	
	last_window_qd_sum_for_debug = bufferbloat_stat->qd_measured_sum -
				bufferbloat_stat->sample_qd_sum_until_last_window;
	if(	last_window_qd_sum_for_debug <= 0 &&
		bufferbloat_stat->last_unwindowed_qd_sample != 0
	){	printf("\nbufferbloat.c %d: ERROR: last_window_qd_sum_for_debug=%f, last_unwindowed_qd_sample=%f\n",
			__LINE__, (float)last_window_qd_sum_for_debug, 
			(float)bufferbloat_stat->last_unwindowed_qd_sample);
		printf("\nqd_measured_sum=%f, sample_qd_sum_until_last_window=%f\
			not_void_windows=%d, qd_measured_count=%d\n",
			(float)bufferbloat_stat->qd_measured_sum, 
			(float)bufferbloat_stat->sample_qd_sum_until_last_window,
			bufferbloat_stat->not_void_windows, 
			bufferbloat_stat->qd_measured_count);
			
		exit(177746);
	}
	
	#endif //of SEVERE_DEBUG

    return windowed_qd;
}

#ifdef SAMPLES_VALIDITY
void chance_is_not_valid(enum analysis_type an_type, 
	enum bufferbloat_analysis_trigger trig, const tcp_pair_addrblock* addr_pair,
	const int dir, const char* type, utp_stat* thisdir_bufferbloat_stat, 
	utp_stat* otherdir_bufferbloat_stat, const int conn_id )
{
	windowed_queueing_delay(an_type, trig, addr_pair, 
		thisdir_bufferbloat_stat, otherdir_bufferbloat_stat, dir, 
		type, conn_id);

	thisdir_bufferbloat_stat->qd_calculation_chances++;

	#ifdef SEVERE_DEBUG
	char an_descr[16];
	#ifdef DATA_TRIGGERED_BUFFERBLOAT_ANALYSIS
	sprintf(an_descr, "%s-%s", (an_type==TCP)? "TCP":"LEDBAT", 
			(trig==ACK_TRIG)? "ACK_TRIG":"DATA_TRIG" );
	#else
	sprintf(an_descr, "%s-%s", (an_type==TCP)? "TCP":"LEDBAT","DATA_TRIG" );	
	#endif
	
	#ifdef SAMPLES_VALIDITY
	//The last queueing delay sample has been absorbed in the window that we
	//have just closed
	thisdir_bufferbloat_stat->last_unwindowed_qd_sample = 0;
	#endif
	
	#endif //of SEVERE_DEBUG
}
#endif

//<aa>:TODO: pass the filedescriptor rather than passing an_type and trig</aa>
#ifdef FORCE_CALL_INLINING
extern inline
#endif
void print_last_window_general(enum analysis_type an_type, 
	enum bufferbloat_analysis_trigger trig, unsigned long long left_edge,
	const tcp_pair_addrblock* addr_pair,
	const utp_stat* bufferbloat_stat_p) 
{
	#ifdef SEVERE_DEBUG
	///////// TAKING CARE OF WINDOW EDGE: begin
	if(left_edge <= bufferbloat_stat_p->last_printed_window_edge)
	{	printf("ERROR in print_last_window_general, line %d\n",__LINE__); 
		exit(413);
	}
	#ifdef SAMPLES_VALIDITY
	if(	bufferbloat_stat_p->last_printed_window_edge != 0 &&
		left_edge != bufferbloat_stat_p->last_printed_window_edge+1
	){	printf("\nERROR in print_last_window_general, line %d, last_printed_window_edge=%d, left_edge=%d\n",
			__LINE__, (int)bufferbloat_stat_p->last_printed_window_edge, (int)left_edge); 
		exit(412);
	}	
	#endif //of SAMPLES_VALIDITY
	///////// TAKING CARE OF WINDOW EDGE: end
	
	
	if(an_type != LEDBAT && an_type != TCP){
		printf("ERROR in print_last_window_general, line %d\n",__LINE__); 
		exit(414);
	}

	if(an_type==TCP && trig!=ACK_TRIG 
		#ifdef DATA_TRIGGERED_BUFFERBLOAT_ANALYSIS
		&& trig!=DATA_TRIG
		#endif
	){
		printf("ERROR in print_last_window_general, line %d: trig vs ledbat\n",
			__LINE__); 
		exit(414);
	}

	if(an_type == LEDBAT && trig != DONT_CARE_TRIG){
		printf("ERROR in print_last_window_general, line %d: trig vs ledbat\n",
			__LINE__); 
		exit(414);
	}

	if( (double)bufferbloat_stat_p->last_window_edge > UINT_MAX){
		printf("ERROR in print_last_window_general, line %d\n",__LINE__); 
		exit(414);
	}

	if(current_time.tv_sec <= left_edge){
		printf("\nline %d: Error in print_last_window_general\n",__LINE__);
		printf("current_time %llu, last_window_edge=%llu, left_edge=%llu. I can print a window only when I decide to close it, and I decide to close it only if I see a packet falling in a following window (in a different second)  \n",
			(unsigned long long)current_time.tv_sec, 
			bufferbloat_stat_p->last_window_edge, left_edge);
		printf("Now, it's like I'm going to close the window in correspondence to a packet falling in the same window. It must not be done\n");
		exit(784145);
	}

	#ifdef ONE_FLOW_ONLY
	if(bufferbloat_stat_p->last_window_edge < latest_window_edge[(int)an_type][(int)trig]) {
		printf("line %d: ERROR in print_last_window_general\n",__LINE__);
		printf("bufferbloat_stat_p->last_window_edge=%u, latest_window_edge=%u\n",
			(unsigned)bufferbloat_stat_p->last_window_edge, 
			(unsigned)latest_window_edge[(int)an_type][(int)trig]);
		char* an_details;
		if(an_type == TCP && trig == ACK_TRIG) 
			an_details = "TCP-ACK_TRIG";
		#ifdef DATA_TRIGGERED_BUFFERBLOAT_ANALYSIS
		else if(an_type == TCP && trig == DATA_TRIG) 
			an_details = "TCP-DATA_TRIG";
		#endif //of DATA_TRIGGERED_BUFFERBLOAT_ANALYSIS
		else if(an_type == LEDBAT) 
			an_details = "LEDBAT";
		else	an_details = "ERROR";
		printf("an_details=%s\n",an_details);

		exit(1274);
	}
	#endif	//of ONE_FLOW_ONLY
	#endif //of SEVERE_DEBUG

	FILE* fp_qd=NULL;
	switch (an_type){
		case TCP:	if(trig == ACK_TRIG)
						fp_qd = fp_tcp_windowed_qd_acktrig_logc;
					#ifdef DATA_TRIGGERED_BUFFERBLOAT_ANALYSIS
					else
						fp_qd = fp_tcp_windowed_qd_datatrig_logc;
					#endif
				break;

		default:	//LEDBAT
				fp_qd = fp_ledbat_windowed_qd_logc; 
				break;
	}

	wfprintf(fp_qd,"%llu ", left_edge);				//1.last_window_edge(seconds)

	wfprintf (fp_qd, "%s %s ",
      	           HostName (addr_pair->a_address),	//2.ip_addr_1
       	           ServiceName (addr_pair->a_port));	//3.port_1
  	wfprintf (fp_qd, "%s %s",
       	           HostName (addr_pair->b_address),	//4.ip_addr_2
       	           ServiceName (addr_pair->b_port));	//5.port_2

}

#ifdef FORCE_CALL_INLINING
extern inline
#endif
void print_last_window_directional(enum analysis_type an_type,
	enum bufferbloat_analysis_trigger trig,
	const utp_stat* bufferbloat_stat, const int conn_id, const char* type,
	const delay_t qd_window, const delay_t window_error)
{
	FILE* fp_logc=NULL;
	switch(an_type){
		case TCP:
			if(trig == ACK_TRIG)
				fp_logc = fp_tcp_windowed_qd_acktrig_logc;
			#ifdef DATA_TRIGGERED_BUFFERBLOAT_ANALYSIS
			else
				fp_logc = fp_tcp_windowed_qd_datatrig_logc;
			#endif
			break;

		default: //LEDBAT
			fp_logc = fp_ledbat_windowed_qd_logc;
	}
	
	int samples_in_win = bufferbloat_stat->qd_measured_count- 
			bufferbloat_stat->qd_samples_until_last_window;
	if(samples_in_win<0){
		printf("ERROR in print_last_window_directional, line %d\n",__LINE__); 
		exit(412);
	}
	
	#ifdef SAMPLES_VALIDITY
	int chances_in_win = 
		bufferbloat_stat->qd_calculation_chances - 
		bufferbloat_stat->qd_calculation_chances_until_last_window;
	#endif

	#ifdef SEVERE_DEBUG
	if (	(qd_window == BUFFEBLOAT_NOSAMPLES && qd_window != BUFFEBLOAT_NOSAMPLES)
	      ||(qd_window != BUFFEBLOAT_NOSAMPLES && qd_window == BUFFEBLOAT_NOSAMPLES)
	){
		printf("ERROR: BUFFERBLOAT_NOSAMPLES inconsistencies\n");exit(447);
	}

	if(an_type != LEDBAT && an_type != TCP){
		printf("ERROR in print_last_window_directional, line %d\n",__LINE__); 
		exit(414);
	}

	if(an_type==TCP && trig!=ACK_TRIG 
		#ifdef DATA_TRIGGERED_BUFFERBLOAT_ANALYSIS
		&& trig!=DATA_TRIG
		#endif
	){
		printf("ERROR in print_last_window_directional, line %d: trig vs ledbat\n",
			__LINE__); 
		exit(414);
	}

	if(an_type == LEDBAT && trig != DONT_CARE_TRIG){
		printf("ERROR in print_last_window_directional, line %d: trig vs ledbat\n",
			__LINE__); 
		exit(414);
	}
	
	#ifdef SAMPLES_VALIDITY
	if(samples_in_win > chances_in_win)
	{	printf("\nline %d: ERROR.\n",__LINE__); exit(555);}
	#endif
	
	#endif //of SEVERE_DEBUG

	wfprintf(fp_logc, " %s",type);			//6-19:type

	if (qd_window == BUFFEBLOAT_NOSAMPLES)
		wfprintf(fp_logc, " - -");
	else
		wfprintf(fp_logc, " %d %d", 
			qd_window,						//7-20
			window_error					//8-21
		);

	delay_t windowed_gross_dly=-1; //milliseconds

	#ifdef SEVERE_DEBUG
	if (samples_in_win>0){
		windowed_gross_dly = //milliseconds
			(bufferbloat_stat->gross_dly_measured_sum - 
			bufferbloat_stat->gross_dly_sum_until_last_window)/
			samples_in_win;
		if(windowed_gross_dly < 0){
			printf("line %d:ERROR in print_last_window_directional: windowed_gross_dly=%f; qd_window=%f\n",
				__LINE__, (float)windowed_gross_dly, (float)qd_window);
			exit(440);
		}
	}

	if(windowed_gross_dly < qd_window){
		printf("line %d:ERROR in print_last_window_directional: windowed_gross_dly=%f; qd_window=%f\n",
			__LINE__, (float)windowed_gross_dly, (float)qd_window);
		exit(441);
	}
	#endif //SEVERE_DEBUG

	wfprintf(fp_logc,DELAY_T_FORMAT_SPECIFIER,
		bufferbloat_stat->qd_max_w1		//9-22 milliseconds
	);

	#ifdef SAMPLES_VALIDITY
	wfprintf(fp_logc," %d",chances_in_win);
										//10-23: chances
	#else
	wfprintf(fp_logc," -");				//10-23
	#endif


	if(windowed_gross_dly == -1)
		wfprintf(fp_logc, " -");		//11-24
	else
		wfprintf(fp_logc, DELAY_T_FORMAT_SPECIFIER,windowed_gross_dly);
										//11-24 milliseconds
	
	wfprintf(fp_logc," %d %d %d",  // %f %f %f %u
		conn_id,						//12-25
		samples_in_win,					//13-26: no_of_qd_samples_in_windows
		bufferbloat_stat->not_void_windows	//14-27: no of not void windows
	);	
	
	wfprintf(fp_logc, DELAY_T_FORMAT_SPECIFIER,
		bufferbloat_stat->qd_measured_sum	//15-28 milliseconds
	);
	
	wfprintf(fp_logc, DELAY_T_FORMAT_SPECIFIER,
		bufferbloat_stat->windowed_qd_sum	//16-29 milliseconds
	);
	
	wfprintf(fp_logc, DELAY_T_FORMAT_SPECIFIER,
		bufferbloat_stat->sample_qd_sum_until_last_window
							//17-30 milliseconds
	);
	
	wfprintf(fp_logc, DELAY_T_FORMAT_SPECIFIER,
		bufferbloat_stat->delay_base		//18-31 (milliseconds)
	);
}

#ifdef SAMPLES_VALIDITY
#ifdef FORCE_CALL_INLINING
extern inline
#endif
void print_void_window(enum analysis_type an_type,  
	enum bufferbloat_analysis_trigger trig, const unsigned long long old_last_left_edge,
	const tcp_pair_addrblock* addr_pair, const utp_stat* thisdir_bufferbloat_stat,
	const utp_stat* otherdir_bufferbloat_stat, const int conn_id, const char* type)
{
	#ifdef SEVERE_DEBUG
	printf("\nbufferbloat.c %d: printing edge %u\n",__LINE__,(unsigned)old_last_left_edge);
	const utp_stat* bufferbloat_stat_p = thisdir_bufferbloat_stat;
	if(current_time.tv_sec <= old_last_left_edge){
		printf("line %d: Error in print_void_window(..)\n",__LINE__);
		printf("current_time %u, last_window_edge=%u. I can print a window only when I decide to close it, and I decide to close it only if I see a packet falling in a following window (in a different second)  \n",
			(unsigned)current_time.tv_sec, 
			(unsigned)bufferbloat_stat_p->last_window_edge);
		printf("Now, it's like I'm going to close the window in correspondence to a packet falling in the same window. It must not be done\n");
		exit(784146);
	}
	#endif
	
	FILE* fp_logc=NULL;
	switch(an_type){
		case TCP:
			if(trig == ACK_TRIG)
				fp_logc = fp_tcp_windowed_qd_acktrig_logc;
			#ifdef DATA_TRIGGERED_BUFFERBLOAT_ANALYSIS
			else
				fp_logc = fp_tcp_windowed_qd_datatrig_logc;
			#endif
			break;

		default: //LEDBAT
			fp_logc = fp_ledbat_windowed_qd_logc;
	}


	print_last_window_general(an_type, trig, old_last_left_edge, addr_pair,
		thisdir_bufferbloat_stat);

	print_last_window_directional(an_type, trig, thisdir_bufferbloat_stat, 
		conn_id, type, BUFFEBLOAT_NOSAMPLES, BUFFEBLOAT_NOSAMPLES);
	print_last_window_directional(an_type, trig, otherdir_bufferbloat_stat, 
		conn_id, type, BUFFEBLOAT_NOSAMPLES, BUFFEBLOAT_NOSAMPLES);
	
	wfprintf(fp_logc,"\n"); fflush(fp_logc);
	
}
#endif

#ifdef FORCE_CALL_INLINING
extern inline
#endif
delay_t windowed_queueing_delay(enum analysis_type an_type, 
	enum bufferbloat_analysis_trigger trig, const tcp_pair_addrblock* addr_pair, 
	utp_stat* thisdir_bufferbloat_stat, utp_stat* otherdir_bufferbloat_stat, int dir, 
	const char* type, const int conn_id )
{
	FILE* fp_logc=NULL;

	#ifdef SEVERE_DEBUG
	if (dir!=C2S && dir!=S2C){
		printf("ERROR: dir not valid in windowed_queueing_delay\n");
		exit(442);
	}

	if (thisdir_bufferbloat_stat == otherdir_bufferbloat_stat){
		printf("line %d: thisdir_bufferbloat_stat == otherdir_bufferbloat_stat\n",__LINE__); exit(11);
	}

	if(an_type != LEDBAT && an_type != TCP){
		printf("ERROR in windowed_queueing_delay, line %d\n",__LINE__); 
		exit(414);
	}

	if(an_type==TCP && trig!=ACK_TRIG 
		#ifdef DATA_TRIGGERED_BUFFERBLOAT_ANALYSIS
		&& trig!=DATA_TRIG
		#endif
	){
		printf("ERROR in windowed_queueing_delay, line %d: trig vs ledbat\n",
			__LINE__); 
		exit(414);
	}

	if(an_type == LEDBAT && trig != DONT_CARE_TRIG){
		printf("ERROR in windowed_queueing_delay, line %d: trig vs ledbat\n",
			__LINE__); 
		exit(414);
	}
	check_direction_consistency_light(thisdir_bufferbloat_stat,
		otherdir_bufferbloat_stat, __LINE__);

	#ifdef ONE_FLOW_ONLY
	if(current_time.tv_sec < latest_window_edge[(int)an_type][(int)trig]) {
		printf("line %d: ERROR in windowed_queueing_delay\n",__LINE__);
		exit(1274);
	}
	#endif
	#endif //of SEVERE_DEBUG

	switch(an_type){
		case TCP:
			if(trig == ACK_TRIG)
				fp_logc = fp_tcp_windowed_qd_acktrig_logc;
			#ifdef DATA_TRIGGERED_BUFFERBLOAT_ANALYSIS
			else
				fp_logc = fp_tcp_windowed_qd_datatrig_logc  ;
			#endif
			break;

		default: //LEDBAT
			fp_logc = fp_ledbat_windowed_qd_logc;
	}

	delay_t qd_window=-1; //milliseconds

	//initialize last_window_edge
	//<aa>TODO: better if we have a single time_zero_w1
	if (thisdir_bufferbloat_stat->last_window_edge == 0){
		//This is the first queueing delay sample we are dealing with. Therefore we
		//set up current_time.tv_sec as the first window edge
	
		//Remember: check_direction_consistency(...) guarantees that if in this
		//direction last_window_edge==0, then also in the opposite direction 
		//utp.last_window_edge==0
		thisdir_bufferbloat_stat->last_window_edge = current_time.tv_sec;
		otherdir_bufferbloat_stat->last_window_edge = current_time.tv_sec;
		#ifdef SEVERE_DEBUG
		#ifdef ONE_FLOW_ONLY
		latest_window_edge[(int)an_type][(int)trig] = current_time.tv_sec;
		check_direction_consistency_light(thisdir_bufferbloat_stat,
			otherdir_bufferbloat_stat, __LINE__);
		#endif
		#endif
	}
	//<aa>TODO: we are computing (last_window_edge - current_time) 2 times: 
	//here and inside close_window(...). It's not efficient</aa>
	else if ( current_time.tv_sec - thisdir_bufferbloat_stat->last_window_edge >= 1)
	{
		unsigned long long old_last_left_edge = thisdir_bufferbloat_stat->last_window_edge;
		
		//More than 1 second has passed from the last window edge. We can close the 
		//window; but, at first, we have to print its values.
		print_last_window_general(an_type, trig, 
			thisdir_bufferbloat_stat->last_window_edge,
			addr_pair, (const utp_stat*) thisdir_bufferbloat_stat );
		delay_t other_qd_window; //milliseconds
		
		#ifdef SEVERE_DEBUG

		#ifdef SAMPLES_VALIDITY		
		//Taking care of window edge
		if(	thisdir_bufferbloat_stat->last_printed_window_edge !=0 &&
			thisdir_bufferbloat_stat->last_window_edge != 
			thisdir_bufferbloat_stat->last_printed_window_edge+1)
		{	printf("\nbufferbloat.c %d: ERROR: last_window_edge=%llu, \
				last_printed_window_edge=%llu\n",
				__LINE__, thisdir_bufferbloat_stat->last_window_edge, 
				thisdir_bufferbloat_stat->last_printed_window_edge); 
			exit(123243);
		}
		#endif //of SAMPLES_VALIDITY
		
		thisdir_bufferbloat_stat->last_printed_window_edge = 
			thisdir_bufferbloat_stat->last_window_edge;
		otherdir_bufferbloat_stat->last_printed_window_edge =
			thisdir_bufferbloat_stat->last_window_edge;
		
		if(current_time.tv_sec <= thisdir_bufferbloat_stat->last_window_edge){
			printf("line %d: Error\n",__LINE__);
			printf("current_time %u, last_window_edge=%u. I can print a window only when I decide to close it, and I decide to close it only if I see a packet falling in a following window (in a different second)  \n",
				(unsigned)current_time.tv_sec, 
				(unsigned)thisdir_bufferbloat_stat->last_window_edge);
			printf("Now, it's like I'm going to close the window in correspondence to a packet falling in the same window. It must not be done\n");
			exit(784146);
		}

		
		#ifdef SAMPLES_VALIDITY
		//We must have seen at least one chance (the one that has led to the previous
		//window closure, in other words the chance immediately after the last closed
		//window right edge)
		if(	thisdir_bufferbloat_stat->qd_calculation_chances - 
			thisdir_bufferbloat_stat->qd_calculation_chances_until_last_window <=0 
			&&
			otherdir_bufferbloat_stat->qd_calculation_chances - 
			otherdir_bufferbloat_stat->qd_calculation_chances_until_last_window <=0 
		){
			printf("\nERROR on line %d: 0 qd chances in both directions\n",__LINE__);
			exit(222);
		}
		#else //SAMPLES_VALIDITY is not defined
		//We must have seen at least one qd sample (the one that has led to the 
		//previous window closure, in other words the chance immediately after 
		//the last closed window right edge)
		if(	thisdir_bufferbloat_stat->qd_measured_count - 
			thisdir_bufferbloat_stat->qd_samples_until_last_window <=0 
			&&
			otherdir_bufferbloat_stat->qd_measured_count - 
			otherdir_bufferbloat_stat->qd_samples_until_last_window <=0 
		){
			printf("\nERROR on line %d: 0 qd samples in both directions\n",__LINE__);
			exit(223);
		}
		#endif //of SAMPLES_VALIDITY
		
		#endif //of SEVERE_DEBUG
		
		//Print C2S first and then S2C
		if (dir==C2S){
			#ifdef SEVERE_DEBUG
			check_direction_consistency_light(thisdir_bufferbloat_stat,
				otherdir_bufferbloat_stat, __LINE__);
			#endif
			qd_window = close_window(an_type, trig, 
				thisdir_bufferbloat_stat, type, conn_id);

			other_qd_window = close_window(an_type, trig, 
				otherdir_bufferbloat_stat, type, conn_id);
			#ifdef SEVERE_DEBUG
			#ifndef SAMPLES_VALIDITY
			if (qd_window == -1 && other_qd_window ==-1){
				printf("\nline %d:ERROR: No pkts in both direction\n",__LINE__);
				exit(987324);
			}
			#endif //of SAMPLES_VALIDITY
			check_direction_consistency_light(thisdir_bufferbloat_stat,
				otherdir_bufferbloat_stat, __LINE__);
			#endif //of SEVERE_DEBUG
		}else{ //dir==S2C
			#ifdef SEVERE_DEBUG
			check_direction_consistency_light(thisdir_bufferbloat_stat,
				otherdir_bufferbloat_stat, __LINE__);
			#endif
			other_qd_window = close_window(an_type, trig, 
				otherdir_bufferbloat_stat, type, conn_id);
			qd_window = close_window(an_type, trig, 
				thisdir_bufferbloat_stat, type, conn_id);
			#ifdef SEVERE_DEBUG
			check_direction_consistency_light(thisdir_bufferbloat_stat,
				otherdir_bufferbloat_stat, __LINE__);
			#endif
		}
		wfprintf(fp_logc,"\n"); fflush(fp_logc);

		#ifdef SEVERE_DEBUG
		//We have just decided to close the window because we saw a packet in this
		//direction. This is the first packet (considering both directions) that 
		//goes beyond the previous window. Therefore, there are no packets beyond
		//the previous window (and consequently in window just closed) that has seen
		//in the other direction.
		otherdir_bufferbloat_stat->last_unwindowed_qd_sample = 0;

		printf("\nWindow closed\n");
		if(old_last_left_edge == 0)
		{	printf("\nline %d: ERROR\n",__LINE__); exit(2411);}
		#endif
		
		#ifdef SAMPLES_VALIDITY
		for(old_last_left_edge++; 
			old_last_left_edge < thisdir_bufferbloat_stat->last_window_edge;
			old_last_left_edge++
		){
			print_void_window(an_type, trig, 
				(const unsigned long long) old_last_left_edge,addr_pair, 
				(const utp_stat*) thisdir_bufferbloat_stat,
				(const utp_stat*) otherdir_bufferbloat_stat, 
				conn_id, type);

			#ifdef SEVERE_DEBUG 
			//Taking care of window edge
			thisdir_bufferbloat_stat->last_printed_window_edge =old_last_left_edge;
			otherdir_bufferbloat_stat->last_printed_window_edge=old_last_left_edge;
			#endif
		}
		#endif

		#ifdef SEVERE_DEBUG
		//After having closed windows, the following quantities must be the same
		if( 	thisdir_bufferbloat_stat->qd_measured_count != 
			thisdir_bufferbloat_stat->qd_samples_until_last_window
			||
			otherdir_bufferbloat_stat->qd_measured_count !=
			otherdir_bufferbloat_stat->qd_samples_until_last_window
		){	printf("\nline %d:ERROR\n",__LINE__); exit(987322); }

		#ifdef SAMPLES_VALIDITY
		if( 	thisdir_bufferbloat_stat->qd_calculation_chances !=
			thisdir_bufferbloat_stat->qd_calculation_chances_until_last_window
			||
			otherdir_bufferbloat_stat->qd_calculation_chances !=
			otherdir_bufferbloat_stat->qd_calculation_chances_until_last_window
		){	printf("\nline %d:ERROR\n",__LINE__); exit(987323); }
		#else //SAMPLES_VALIDITY is not defined
		if (qd_window == -1 && other_qd_window ==-1){
			printf("\nline %d:ERROR: No qd sampkes in both direction\n",__LINE__);
			exit(987324);
		}
		#endif //of SAMPLES_VALIDITY
		check_direction_consistency_light(thisdir_bufferbloat_stat,
			otherdir_bufferbloat_stat, __LINE__);
		#endif //of SEVERE_DEBUG
	}

	#ifdef SEVERE_DEBUG
	check_direction_consistency_light(thisdir_bufferbloat_stat,
			otherdir_bufferbloat_stat, __LINE__);
	#endif
	return qd_window;
}//windowed_queueing_delay

#ifdef SEVERE_DEBUG
void check_direction_consistency_light(const utp_stat* this_bufferbloat_stat, 
	const utp_stat* other_bufferbloat_stat, int caller_line)
{
	if(	this_bufferbloat_stat->last_printed_window_edge !=
		other_bufferbloat_stat->last_printed_window_edge
	){
		printf("line %d: Error in check_direction_consistency_light\n",__LINE__);
		exit(6697);
	}
	
	if(this_bufferbloat_stat==other_bufferbloat_stat){
		printf("line %d: Error in check_direction_consistency_light\n",__LINE__);
		exit(6698);
	}

	timeval last_window_edge, other_last_window_edge;
	last_window_edge.tv_sec = this_bufferbloat_stat->last_window_edge;
	last_window_edge.tv_usec = 0;

	other_last_window_edge.tv_sec = other_bufferbloat_stat->last_window_edge;
	other_last_window_edge.tv_usec = 0;

	if ( elapsed(last_window_edge, other_last_window_edge) != 0){
		printf("\ncheck_direction_consistency light called in line %d\n", 
			caller_line);
		printf("\nline %dERROR b. last_window_edge=%u; other_last_window_edge=%u\n",__LINE__,
			(unsigned)last_window_edge.tv_sec, 
			(unsigned)other_last_window_edge.tv_sec);
		exit(1000);
	}

	if(	last_window_edge.tv_sec != other_last_window_edge.tv_sec ||
		last_window_edge.tv_usec != other_last_window_edge.tv_usec
	){
		printf("\ncheck_direction_consistency light called in line %d\n", 
			caller_line);
		printf("\nline %d: ERROR b. last_window_edge=%u; other_last_window_edge=%u\n",__LINE__,
			(unsigned)last_window_edge.tv_sec, 
			(unsigned)other_last_window_edge.tv_sec);
		exit(1008);
	}

	if(	elapsed(last_window_edge, current_time)<0 
	      ||elapsed(other_last_window_edge, current_time)<0
	){
		printf("\ncheck_direction_consistency light called in line %d\n", 
			caller_line);
		printf("\nline %dERROR b. last_window_edge=%u; other_last_window_edge=%u; current_time=%u\n",
			__LINE__,(unsigned)last_window_edge.tv_sec, 
			(unsigned)other_last_window_edge.tv_sec,
			(unsigned)current_time.tv_sec);
		exit(1070);
	}


	if(	  this_bufferbloat_stat->gross_dly_measured_sum - 
		  this_bufferbloat_stat->gross_dly_sum_until_last_window
		< this_bufferbloat_stat->qd_measured_sum - 
		  this_bufferbloat_stat->sample_qd_sum_until_last_window
	){
		printf("\ncheck_direction_consistency light called in line %d\n", 
			caller_line);
		printf("line %d:ERROR gross_dly_win_sum=%f, qd_dly_win_sum=%f\n",__LINE__,
			(float)this_bufferbloat_stat->gross_dly_measured_sum - 
			(float)this_bufferbloat_stat->gross_dly_sum_until_last_window,
			(float)this_bufferbloat_stat->qd_measured_sum - 
			(float)this_bufferbloat_stat->sample_qd_sum_until_last_window
		);
		exit(223);
	}

	if(	  other_bufferbloat_stat->gross_dly_measured_sum - 
		  other_bufferbloat_stat->gross_dly_sum_until_last_window
		< other_bufferbloat_stat->qd_measured_sum - 
		  other_bufferbloat_stat->sample_qd_sum_until_last_window
	){
		printf("\ncheck_direction_consistency light called in line %d\n", 
			caller_line);
		printf("line %d:ERROR \n",__LINE__); exit(223);
	}
	
	if(	!
		(
			this_bufferbloat_stat->qd_samples_until_last_window <=
			this_bufferbloat_stat->qd_measured_count
		)
	){	
		printf("\ncheck_direction_consistency light called in line %d\n", 
			caller_line);
		printf("qd_measured_count=%d, qd_samples_until_last_window=%d\n",
			this_bufferbloat_stat->qd_measured_count,
			this_bufferbloat_stat->qd_samples_until_last_window);
		printf("line %d:ERROR \n",__LINE__); exit(224);
	}


	if(	!
		(
			other_bufferbloat_stat->qd_samples_until_last_window <=
			other_bufferbloat_stat->qd_measured_count
		)
	){	
		printf("\ncheck_direction_consistency light called in line %d\n", 
			caller_line);
		printf("line %d:ERROR \n",__LINE__); exit(228);
	}

	#ifdef SAMPLES_VALIDITY
	if(	!
		(
			this_bufferbloat_stat->qd_calculation_chances_until_last_window <=
			this_bufferbloat_stat->qd_calculation_chances
			&&
			other_bufferbloat_stat->qd_calculation_chances_until_last_window <=
			other_bufferbloat_stat->qd_calculation_chances
		)
	){	
		printf("\ncheck_direction_consistency light called in line %d\n", 
			caller_line);
		printf("bufferbloat.c %d:ERROR: chances_until_last_window must be less or equal to qd_calculation_chances\n",
			__LINE__);
		printf("thisdir_chances_until_last_window=%d, thisdir_chances=%d, otherdir_chances_until_last_window=%d, otherdir_chances=%d\n",
			this_bufferbloat_stat->qd_calculation_chances_until_last_window, 
			this_bufferbloat_stat->qd_calculation_chances,
			other_bufferbloat_stat->qd_calculation_chances_until_last_window,
			other_bufferbloat_stat->qd_calculation_chances); 
		exit(227);
	}
	
	if(	!
		(
			this_bufferbloat_stat->qd_measured_count <= 
			this_bufferbloat_stat->qd_calculation_chances
			&&
			other_bufferbloat_stat->qd_measured_count <= 
			other_bufferbloat_stat->qd_calculation_chances
			&&
			this_bufferbloat_stat->qd_samples_until_last_window <= 
			this_bufferbloat_stat->qd_calculation_chances_until_last_window
			&&
			other_bufferbloat_stat->qd_samples_until_last_window <= 
			other_bufferbloat_stat->qd_calculation_chances_until_last_window
		)
	){	
		printf("\ncheck_direction_consistency light called in line %d\n", 
			caller_line);
		printf("line %d:ERROR \n",__LINE__); exit(225);
	}
	#endif //of SAMPLES_VALIDITY
	
}
#endif //of SEVERE_DEBUG

#ifdef SEVERE_DEBUG
void check_direction_consistency(enum analysis_type an_type, 
	enum bufferbloat_analysis_trigger trig, void* thisdir_, int call_line_number)
{
	tcb *thisdir_tcp, *otherdir_tcp; 
	ucb* thisdir_ledbat, *otherdir_ledbat;
	void* thisdir_parent, *otherdir_parent;
	timeval thisdir_last_packet_time, otherdir_last_packet_time;
	utp_stat *thisdir_bufferbloat_stat, *otherdir_bufferbloat_stat;

	if(an_type != LEDBAT && an_type != TCP){
		printf("ERROR in check_direction_consistency, line %d\n",__LINE__); 
		exit(414);
	}

	if(an_type==TCP && trig!=ACK_TRIG 
		#ifdef DATA_TRIGGERED_BUFFERBLOAT_ANALYSIS
		&& trig!=DATA_TRIG
		#endif
	){
		printf("ERROR in check_direction_consistency, line %d\n",
			__LINE__); 
		exit(414);
	}

	if(an_type == LEDBAT && trig != DONT_CARE_TRIG){
		printf("ERROR in check_direction_consistency, line %d\n",
			__LINE__); 
		exit(414);
	}
	
	switch (an_type){
		case TCP:
			thisdir_tcp = (tcb*) thisdir_;
			
			if (
				thisdir_tcp == &(thisdir_tcp->ptp->s2c) 
			     && thisdir_tcp != &(thisdir_tcp->ptp->c2s)
			)
				otherdir_tcp = &(thisdir_tcp->ptp->c2s);

			else if (
				thisdir_tcp == &(thisdir_tcp->ptp->c2s) 
			     && thisdir_tcp != &(thisdir_tcp->ptp->s2c)
			)
				otherdir_tcp = &(thisdir_tcp->ptp->s2c);

			else{
				printf("ERROR a"); exit(7);
			}

			#ifdef DATA_TRIGGERED_BUFFERBLOAT_ANALYSIS
			if(trig == DATA_TRIG){
				thisdir_bufferbloat_stat = 
					&(thisdir_tcp->bufferbloat_stat_data_triggered);
				otherdir_bufferbloat_stat = 
					&(otherdir_tcp->bufferbloat_stat_data_triggered);
			} else 
			#endif //of DATA_TRIGGERED_BUFFERBLOAT_ANALYSIS
			if(trig == ACK_TRIG) {
				thisdir_bufferbloat_stat = 
					&(thisdir_tcp->bufferbloat_stat_ack_triggered);
				otherdir_bufferbloat_stat = 
					&(otherdir_tcp->bufferbloat_stat_ack_triggered);
			}else {
				printf("ERROR in check_direction_consistency, line %d",
					__LINE__);
				exit(5258);
			}

			thisdir_parent = (void*) thisdir_tcp->ptp;
			otherdir_parent = (void*) otherdir_tcp->ptp;
			thisdir_last_packet_time = thisdir_tcp->last_time;
			otherdir_last_packet_time = otherdir_tcp->last_time;
			break;

		case LEDBAT:
			if(trig!= DONT_CARE_TRIG){
				printf("ERROR: ledbat analysis should not care about trigger");
				exit(336);
			}

			thisdir_ledbat = (ucb*) thisdir_;
			if (
				thisdir_ledbat == &(thisdir_ledbat->pup->s2c)
			     && thisdir_ledbat != &(thisdir_ledbat->pup->c2s)
			)
				otherdir_ledbat = &(thisdir_ledbat->pup->c2s);

			else if (
				thisdir_ledbat == &(thisdir_ledbat->pup->c2s) 
			     && thisdir_ledbat != &(thisdir_ledbat->pup->s2c)
			)
				otherdir_ledbat = &(thisdir_ledbat->pup->s2c);

			else{
				printf("ERROR a"); exit(7);
			}

			thisdir_bufferbloat_stat = &(thisdir_ledbat->utp);
			otherdir_bufferbloat_stat = &(otherdir_ledbat->utp);

			thisdir_parent = (void*) thisdir_ledbat->pup;
			otherdir_parent = (void*) otherdir_ledbat->pup;
			thisdir_last_packet_time = thisdir_ledbat->last_pkt_time;
			otherdir_last_packet_time = otherdir_ledbat->last_pkt_time;
			break;

		default: 
			printf("check_direction_consistency: line %d: an_type not recognized",
				__LINE__);
			exit(544452);
	}

	check_direction_consistency_light(thisdir_bufferbloat_stat, 
		otherdir_bufferbloat_stat,call_line_number);
	
	if (thisdir_parent != otherdir_parent){
		printf("\ncheck_direction_consistency called in line %d\n", call_line_number);
		printf("\nERROR: Different pups\n");exit(21212);
	}

	if (	elapsed(otherdir_last_packet_time, current_time) < 0 ||
		elapsed(thisdir_last_packet_time, current_time) < 0   ){
		printf("\nline %d: ERROR\n",__LINE__); exit(473);	
	}
}
#endif //of SEVERE_DEBUG

#ifdef FORCE_CALL_INLINING
extern inline
#endif
void update_following_left_edge(utp_stat* bufferbloat_stat){
	//Compute the left edge of the following not void window

	#ifdef SEVERE_DEBUG
	//offset is the time(seconds) from the future window left edge and current_time
	unsigned long long offset = 
		current_time.tv_sec - bufferbloat_stat->last_window_edge;
	//offset corresponds to the number of void windows between the last_window_edge and 
	//current_time

	if(current_time.tv_sec <= bufferbloat_stat->last_window_edge){
		printf("line %d: Error in update_following_left_edge\n",__LINE__);
		printf("current_time %u, last_window_edge=%u \n",
			(unsigned)current_time.tv_sec, 
			(unsigned)bufferbloat_stat->last_window_edge);
		exit(784145);
	}

	timeval last_window_edge;
	last_window_edge.tv_sec = bufferbloat_stat->last_window_edge;
	last_window_edge.tv_usec = 0;

	if (	!
		(	elapsed(last_window_edge, current_time) >= 1e6*offset &&
			elapsed(last_window_edge, current_time) <= 1e6*(offset+1)    )
	){
		printf("\nline.c %d: ERROR:\n dir->utp.last_window_edge=%llu;\n current_time=%llus%lluus;\n offset=%llu\n elapsed(last_window_edge, current_time)=%f\n", 
			__LINE__, bufferbloat_stat->last_window_edge, current_time.tv_sec,
			( (long long unsigned) (current_time.tv_usec) ) , (long long unsigned)offset, 
			elapsed(last_window_edge, current_time) );
		exit(978);
	}
	#endif

	bufferbloat_stat->last_window_edge = current_time.tv_sec;
}


#ifdef FORCE_CALL_INLINING
extern inline
#endif
delay_t close_window(enum analysis_type an_type, enum bufferbloat_analysis_trigger trig,
	utp_stat* bufferbloat_stat, const char* type, int conn_id)
{
	delay_t qd_window = -1;
	float window_error;
	delay_t last_window_qd_sum=-1;

	#ifdef SEVERE_DEBUG
	if(bufferbloat_stat->qd_measured_count < bufferbloat_stat->qd_samples_until_last_window){
		printf("ERROR in print_last_window_general, line %d, qd_measured_count=%u,qd_samples_until_last_window=%u\n",
			__LINE__, bufferbloat_stat->qd_measured_count, bufferbloat_stat->qd_samples_until_last_window); 
		exit(413);
	}

	if(an_type != LEDBAT && an_type != TCP){
		printf("ERROR in print_last_window_general, line %d\n",__LINE__); 
		exit(414);
	}

	if(an_type==TCP && trig!=ACK_TRIG 
		#ifdef DATA_TRIGGERED_BUFFERBLOAT_ANALYSIS
		&& trig!=DATA_TRIG
		#endif
	){
		printf("ERROR in print_last_window_general, line %d: trig vs ledbat\n",
			__LINE__); 
		exit(414);
	}

	if(an_type == LEDBAT && trig != DONT_CARE_TRIG){
		printf("ERROR in print_last_window_general, line %d: trig vs ledbat\n",
			__LINE__); 
		exit(414);
	}

	if(current_time.tv_sec <= bufferbloat_stat->last_window_edge){
		printf("line %d: Error in update_following_left_edge\n",__LINE__);
		printf("current_time %u, last_window_edge=%u \n",
			(unsigned)current_time.tv_sec, 
			(unsigned)bufferbloat_stat->last_window_edge);
		exit(784145);
	}
	#endif

	//number of packets in the window we are going to close (not including the last packet)
	int qd_samples_in_win = //milliseconds
		bufferbloat_stat->qd_measured_count- 
		bufferbloat_stat->qd_samples_until_last_window;

	if (qd_samples_in_win != 0){
		//Some pkts have been seen in this direction in the previous window
		last_window_qd_sum = bufferbloat_stat->qd_measured_sum - 
			bufferbloat_stat->sample_qd_sum_until_last_window;

		#ifdef SEVERE_DEBUG
		if(last_window_qd_sum <= 0 && bufferbloat_stat->last_unwindowed_qd_sample != 0)
		{	printf("\nbufferbloat.c %d: last_window_qd_sum=%f, last_unwindowed_qd_sample=%f\n",
				__LINE__, (float)last_window_qd_sum, 
				(float)bufferbloat_stat->last_unwindowed_qd_sample);
			printf("\nqd_measured_sum=%f, sample_qd_sum_until_last_window=%f\
				not_void_windows=%d, qd_measured_count=%d\n",
				(float)bufferbloat_stat->qd_measured_sum, 
				(float)bufferbloat_stat->sample_qd_sum_until_last_window,
				bufferbloat_stat->not_void_windows, 
				bufferbloat_stat->qd_measured_count);
			
			exit(177747);
		}
		#endif

		qd_window= last_window_qd_sum/qd_samples_in_win;
		
		#ifdef SEVERE_DEBUG
		//Precise queueing delay (not rounded)
		float precise_window_qd = 
				(float)(bufferbloat_stat->qd_measured_sum - 
				bufferbloat_stat->sample_qd_sum_until_last_window)/
				qd_samples_in_win;
				
		if(qd_window < 1)
		{	printf("\nbufferbloat.c %d: WARNING qd_window=%ld, qd_samples_in_win=%d, last_window_qd_sum=%ld, precise_window_qd=%f\n",
				__LINE__, qd_window, qd_samples_in_win, last_window_qd_sum,
				precise_window_qd);
		}
		#endif

		if(	(precise_window_qd == 0 || qd_samples_in_win == 0) &&
			bufferbloat_stat->last_unwindowed_qd_sample!= 0
		){	printf("\nbufferbloat.c %d\n", __LINE__);
			printf("ERROR: if the windowed queueing delay is 0, all the queueing \n\
				delay samples must be 0. Therefore the last qd sample of the window\n\
				must be 0. If there are no samples in the window, it means that all \n\
				the queueing delay samples have been inserted in previous windows. \
				Last_unwindowed_qd_sample must be 0\n");
			printf("qd_samples_in_win=%d, window_qd=%f, last_unwindowed_qd_sample=%f, last_window_qd_sum=%f\n",
				qd_samples_in_win, (float)qd_window, 
				(float)bufferbloat_stat->last_unwindowed_qd_sample, 
				(float)last_window_qd_sum);
			printf("precise_window_qd = %f\n", precise_window_qd);
			exit(41774);
		}
	}

	//milliseconds
	window_error=Stdev(bufferbloat_stat->qd_measured_sum - bufferbloat_stat->sample_qd_sum_until_last_window, 
		      bufferbloat_stat->qd_measured_sum2 - bufferbloat_stat->sample_qd_sum2_until_last_window,
		      bufferbloat_stat->qd_measured_count - bufferbloat_stat->qd_samples_until_last_window );
		
	#ifdef SEVERE_DEBUG
	if (bufferbloat_stat->qd_measured_sum - bufferbloat_stat->sample_qd_sum_until_last_window < 0){
		printf("\n\n\n\nline %d: ERROR: qd_measured_sum(%f) < sample_qd_sum_until_last_window(%f)\n\n\n",
			__LINE__,(float)bufferbloat_stat->qd_measured_sum, 
			(float)bufferbloat_stat->sample_qd_sum_until_last_window);
		exit(-9987);
	}
		
	if (bufferbloat_stat->sample_qd_sum_until_last_window < 0){
		printf("\n\n\nline %d: ERROR: sample_qd_sum_until_last_window(%f) < 0\n\n\n\n",
			__LINE__,(float)bufferbloat_stat->sample_qd_sum_until_last_window);
		exit(-9911);
	}

	if(qd_samples_in_win == 0 && qd_window != -1){
		printf("ERROR on line %d in close_window(...): qd_samples_in_win=%d; qd_window=%f\n", 
			__LINE__, qd_samples_in_win, (float)qd_window); 
		exit(558);
	}
		
	delay_t last_window_gross_dly_sum = 
			bufferbloat_stat->gross_dly_measured_sum - 
			bufferbloat_stat->gross_dly_sum_until_last_window;

	if(last_window_gross_dly_sum - last_window_qd_sum < 0){
		printf("last_window_gross_dly_sum == last_window_qd_sum ? %d\n",
			(last_window_gross_dly_sum == last_window_qd_sum) ? 1:0);
		printf("line %d:ERROR in close_window: last_window_gross_dly_sum=%f; last_window_qd_sum=%f\n",
			__LINE__, (float)last_window_gross_dly_sum, 
			(float)last_window_qd_sum);
		exit(440);
	}

	if(qd_samples_in_win != 0)
	{	delay_t windowed_gross_dly = 	
			last_window_gross_dly_sum /	(delay_t)qd_samples_in_win;
		windowed_gross_dly = floor(windowed_gross_dly);
		if( floor( windowed_gross_dly - qd_window ) < 0 ){
			//We use here the floor function because of some issues with floating 
			//point numbers (in the case that delay_t is float ot double)
			printf("line %d:ERROR in close_window: windowed_gross_dly=%f; qd_window=%f, difference=%f, last_window_gross_dly_sum=%f, last_window_qd_sum=%f, qd_samples_in_win=%f, \n",
				__LINE__, (float)windowed_gross_dly, (float)qd_window, 
				(float)windowed_gross_dly-qd_window,
				(float)last_window_gross_dly_sum, (float)last_window_qd_sum, 
				(float)qd_samples_in_win);
			printf("Calculating again: windowed_gross_dly=%f, qd_window=%f\n",
					last_window_gross_dly_sum/(float)qd_samples_in_win, last_window_qd_sum/(float)qd_samples_in_win);
			printf("last_window_gross_dly_sum == last_window_qd_sum ? %d\n",
				(last_window_gross_dly_sum == last_window_qd_sum) ? 1:0);
			exit(441);
		}
	}
	#endif //of SEVERE_DEBUG

	print_last_window_directional(an_type, trig,bufferbloat_stat, conn_id, type, 
		qd_window, window_error);
	
	update_bufferbloat_windowed_values( bufferbloat_stat, qd_window, qd_samples_in_win );
	update_following_left_edge( bufferbloat_stat );	
	return qd_window;
}// end of close_window(...)

#ifdef FORCE_CALL_INLINING
extern inline
#endif
void update_bufferbloat_windowed_values(utp_stat* bufferbloat_stat, delay_t window_qd, 
	int qd_samples_in_win)
{	
	#ifdef SEVERE_DEBUG
	delay_t sample_qd_sum_until_last_window_old = 
		bufferbloat_stat->sample_qd_sum_until_last_window;
	delay_t qd_measured_sum_old=
		bufferbloat_stat->qd_measured_sum;
	int qd_samples_until_last_window_old = 
		bufferbloat_stat->qd_samples_until_last_window;
	int qd_measured_count_old =
		bufferbloat_stat->qd_measured_count;
	delay_t sample_qd_sum2_until_last_window_old = 
		bufferbloat_stat->sample_qd_sum2_until_last_window;
	delay_t qd_measured_sum2_old =
		bufferbloat_stat->qd_measured_sum2;
	delay_t gross_dly_sum_until_last_window_old =
		bufferbloat_stat->gross_dly_sum_until_last_window;
	delay_t gross_dly_measured_sum_old = 
		bufferbloat_stat->gross_dly_measured_sum;

	#ifdef SAMPLES_VALIDITY
	int qd_calculation_chances_until_last_window_old = 
		bufferbloat_stat->qd_calculation_chances_until_last_window;
	int qd_calculation_chances_old =
		bufferbloat_stat->qd_calculation_chances;
	#endif	


	if(qd_samples_in_win == 0)
	{	//All window values should remain unchanged
		if(	!
			(bufferbloat_stat->sample_qd_sum_until_last_window ==
			 bufferbloat_stat->qd_measured_sum
			 &&
			 bufferbloat_stat->qd_samples_until_last_window ==
			 bufferbloat_stat->qd_measured_count
			 &&
			 bufferbloat_stat->sample_qd_sum2_until_last_window ==
			 bufferbloat_stat->qd_measured_sum2
			 &&
			 bufferbloat_stat->gross_dly_sum_until_last_window ==
			 bufferbloat_stat->gross_dly_measured_sum
			)
		){	printf("bufferbloat.c %d: ERROR", __LINE__); exit(654);}
	
	}
	#endif

	if(qd_samples_in_win != 0)
	{	bufferbloat_stat->sample_qd_sum_until_last_window = 
			bufferbloat_stat->qd_measured_sum;
		bufferbloat_stat->qd_samples_until_last_window = 
			bufferbloat_stat->qd_measured_count;
		bufferbloat_stat->sample_qd_sum2_until_last_window = 
			bufferbloat_stat->qd_measured_sum2;

		//stqd_max_w1atistics
		bufferbloat_stat->not_void_windows++;
		bufferbloat_stat->windowed_qd_sum += window_qd;
		bufferbloat_stat->windowed_qd_sum2 += ((window_qd)*(window_qd));

		#ifdef SEVERE_DEBUG
		bufferbloat_stat->gross_dly_sum_until_last_window =
			bufferbloat_stat->gross_dly_measured_sum;
		#endif
	}
	
	#ifdef SAMPLES_VALIDITY
	bufferbloat_stat->qd_calculation_chances_until_last_window = 
	bufferbloat_stat->qd_calculation_chances;
	
	#ifdef SEVERE_DEBUG
	if(bufferbloat_stat->qd_calculation_chances_until_last_window>1000000)
	{	printf("bufferbloat.c %d: ERROR",__LINE__);exit(6553);}
	#endif
	#endif //of SAMPLES_VALIDITY

	#ifdef SEVERE_DEBUG
	sample_qd_sum_until_last_window_old += 
		qd_measured_sum_old - sample_qd_sum_until_last_window_old;
	qd_samples_until_last_window_old += 
		qd_measured_count_old - qd_samples_until_last_window_old;
	sample_qd_sum2_until_last_window_old += 
		qd_measured_sum2_old - sample_qd_sum2_until_last_window_old;
	gross_dly_sum_until_last_window_old += 
		gross_dly_measured_sum_old - gross_dly_sum_until_last_window_old;
		
	if(	bufferbloat_stat->sample_qd_sum_until_last_window !=
		sample_qd_sum_until_last_window_old
	){	printf("line %d: ERROR in close_window(..)\n",__LINE__); exit(5487); }

	if(	bufferbloat_stat->qd_samples_until_last_window !=
		qd_samples_until_last_window_old
	){	printf("line %d: ERROR in close_window(..)\n",__LINE__); exit(5487); }

	if(	bufferbloat_stat->sample_qd_sum2_until_last_window !=
		sample_qd_sum2_until_last_window_old
	){	printf("line %d: ERROR in close_window(..)\n",__LINE__); exit(5487); }
	
	if(	bufferbloat_stat->gross_dly_sum_until_last_window !=
		gross_dly_sum_until_last_window_old
	){	printf("line %d: ERROR in close_window(..)\n",__LINE__); exit(5487); }

	#ifdef SAMPLES_VALIDITY
	qd_calculation_chances_until_last_window_old += 
		qd_calculation_chances_old - qd_calculation_chances_until_last_window_old;

	if(	bufferbloat_stat->qd_calculation_chances_until_last_window !=
		qd_calculation_chances_until_last_window_old
	){	printf("bufferbloat %d: ERROR in close_window(...)\n",__LINE__);
	 	printf("After the window values are updated, calculation_chances_until_last_window should be equal to calculation_chances\n");
	 	printf("qd_calculation_chances_until_last_window_old=%d, calculation_chances_until_last_window=%d\n",
	 		qd_calculation_chances_until_last_window_old,
	 		bufferbloat_stat->qd_calculation_chances_until_last_window);
	 	exit(5487); 
	 }
	#endif	

	if(qd_samples_in_win==0 && window_qd!=-1)
	{	printf("line %d: ERROR in close_window(..)\n",__LINE__); exit(5488); }
		
	#endif //of SEVERE_DEBUG

	#if defined(SEVERE_DEBUG) && defined(ONE_FLOW_ONLY)
	latest_window_edge[(int)an_type][(int)trig] = current_time.tv_sec;
	#endif
}

//</aa>
#endif //of BUFFERBLOAT_ANALYSIS
