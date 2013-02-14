/*
 *
 * Copyright (c) 2006
 *      Politecnico di Torino.  All rights reserved.
		 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * For bug report and other information please visit Tstat site:
 * http://tstat.polito.it
 *
 * Tstat is deeply based on TCPTRACE. The authors would like to thank
 * Shawn Ostermann for the development of TCPTRACE.
 *
*/

/**
 * <aa>
 * References
 * [ledbat_draft]: "Low Extra Delay Background Transport (LEDBAT) draft-ietf-ledbat-congestion-10.txt"
 * [utp_draft]: "uTorrent transport protocol" - http://www.bittorrent.org/beps/bep_0029.html
 * </aa>
 */


#include "tstat.h"

/* define LEDBAT_DEBUG if you want to see all identified pkts */
#define LEDBAT_DEBUG

//Use it as a signal when there are no samples in a window
#define NOSAMPLES -1

extern FILE *fp_ledbat_logc;

#ifdef LEDBAT_WINDOW_CHECK
extern FILE *fp_ledbat_window_logc;
extern FILE *fp_ledbat_window_andrea_logc;
#endif


extern Bool log_engine;
extern int ledbat_window;


float alpha=0.5;


static int is_utp_pkt(struct ip *pip, void *pproto, void *pdir, void *plast);


void update_delay_base(u_int32_t time_diff, u_int32_t time_ms, ucb *thisdir);

/**
 * It returns the baseline, i.e. the minimum of the last DELAY_BASE_HISTORY one-way delays
 */
u_int32_t min_delay_base(ucb *thisdir);


/**
 * <aa> It returns 1 if lhs<rhs, 0 otherwise</aa>
 */
int wrapping_compare_less(u_int32_t lhs, u_int32_t rhs); //libutp

//<aa>
#ifdef SEVERE_DEBUG
//Check if the direction of the current packet and the opposite direction are handled
//consistently. If it is not the case, the program will terminate
void check_direction_consistency(ucb* thisdir, int );
#endif
//</aa>

//<aa>
//the length of a string to store the longest ipv6 address
//http://stackoverflow.com/questions/3455320/size-for-storing-ipv4-ipv6-addresses-as-a-string
#define IPV6_ADDR_STR_LEN 40

//For each packet, the addresses of the two communicating parties are stored here
char a_address[IPV6_ADDR_STR_LEN];
char b_address[IPV6_ADDR_STR_LEN];
//</aa>



void
BitTorrent_init ()
{

#ifdef LEDBAT_DEBUG
	fprintf(fp_stdout, "\n1:ipsrc 2:portsrc 3:ipdest 4:portdest 5:uTPpkt_len 6:utP_version 7:uTP_type 8:uTP_extensions 9:uTP_connID 10:uTP_seqnum 11:uTP_acknum 12:uTP_timeMS 13:uTP_OWD 14:uTP_winsize 15:uTP_basedelay 16:uTP_queuingdelay_float[ms] 17:uTP_queuingdelay_int[ms] 18:last_update_time 19:uTP_ewma 20:qd_w1sec 21:st_dev_w1sec 22:max_qd_w1sec 23:floor(q/w)_w1sec 24:count(samples in w)_w1sec 25--29:w1b 30--34:w5 35:99percentile 36:95percentile 37:extensions? 38:type_ext? 39:first_word_BitTorrent_msg\n ");
#endif


}


//return null
struct utp_hdr *
getBitTorrent (void *pproto, int tproto, void *pdir, void *plast)
{

  void *theheader;
  theheader = ((char *) pproto + 8);

  if (tproto == PROTOCOL_UDP) {


  if ((u_long) theheader + (sizeof (struct utp_hdr)) - 1 > (u_long) plast)
    {
      /*Part of the header UTP is missing*/
      return (NULL);
    }
  else
    {
      return (struct utp_hdr *) theheader;

    }
    } /* protocol = TCP */
      return (NULL);
}



void parser_BitTorrentMessages (void * pp, int tproto, void *pdir,int dir, void *hdr, void *plast){
	

	if (tproto==PROTOCOL_TCP) return;
    	    
        ucb *thisdir, *otherdir;
        thisdir = ( ucb *) pdir;
        otherdir = (ucb *)((dir == C2S) ? &(thisdir->pup->s2c) : &(thisdir->pup->c2s));

	//<aa>TODO: remove this check
	if (dir!=S2C && dir!=C2S){
		printf("dir=%d\n", dir); exit(75);
	}
	if (thisdir->dir == 0)
		//thisdir->dir not already initialized
		thisdir->dir = dir;
	else if (dir != thisdir->dir){
		printf("dir=%d, thisdir->dir=%d", dir, thisdir->dir); exit(74);
	}
	//</aa>

        void *streamBT;
        streamBT=((u_int32_t *)pp);
                
        u_long streamBT_len;
        streamBT_len=(u_long)streamBT - (u_long)plast;

        char peerID[9];
        char infoHASH[21];
                        

	if ((ntohl(*(u_int32_t *)streamBT) == 0x13426974) ){

        	memcpy(infoHASH, (((u_int32_t *)streamBT+5+2)), 8  );
                memcpy(peerID, (((u_int32_t *)streamBT+5+2+5)), 8 );

//araldo!!
//#define CENSURE_NON_PRINTABLE
/*
#ifdef CENSURE_NON_PRINTABLE
                int i=0;           
               	while (i<8){
                	if ( peerID[i]>=122 || (peerID[i])<=47 ) {
	                        peerID[i]='-';
                        }
                        i++;
                 }

                i=0;
                while (i<20){
                	if ( infoHASH[i]>=122 || infoHASH[i]<=47 ) {
                        	infoHASH[i]='.';
                        }
                        i++;
                }
#endif
*/

                strncpy(otherdir->utp.infoHASH, infoHASH,20);
                strncpy(otherdir->utp.peerID, peerID, 8);
        }
}//parser_BitTorrentMessages (ongoing)




//-----------------------------------------/* BitTorrent UDP */----------------------------------------------

int is_utp_pkt(struct ip *pip, void *pproto, void *pdir, void *plast){
	
  u_int32_t *ppayload = NULL;
  u_int8_t check_ver_type, check_ext, check_next_ext, check_len_ext;
  ppayload =  ((u_int32_t *) pproto) +2; /* 32bit*2 for udp header */
  check_ver_type=*((u_int8_t *)ppayload);
  check_ext= *((u_int8_t *)ppayload + 1);
  check_next_ext=*((u_int8_t *)(ppayload+5));
  check_len_ext=*((u_int8_t *)(ppayload+5) +1);

				  

	switch (check_ver_type){
	  
	  case 0x01:
		  if ((check_ext == 0x00) || (check_ext == 0x02)  ) {
			  //return UTP_DATA;
			  if ((check_ext==0x02) && (!(check_next_ext!=0x00))) 
				  return NOT_UTP;
			  else
			  	return UTP_DATA;	  
		  }
			

	  case 0x11:
		  if ((check_ext == 0x00) || (check_ext == 0x02)  ) {
			  //return UTP_FIN;
			  if ((check_ext==0x02) && (!(check_next_ext!=0x00))) 
				  return NOT_UTP;
			  else
			  	return UTP_FIN;

		  }
		  
	  case 0x21:

		  if ((check_ext == 0x00) || (check_ext == 0x02)  ) {
		 		if ((check_ext==0x02) && (!(check_next_ext!=0x00))) 
					return NOT_UTP;			  	
				return UTP_STATE_ACK;				
		  }
			
		    if ((check_ext == 0x01) && (check_next_ext==0x00)) {
			  return UTP_STATE_SACK;
		  }
		    

	  case 0x31:
		    if ((check_ext == 0x00) || (check_ext == 0x02)  ) {
			  //return UTP_RESET;
				  if ((check_ext==0x02) && (!(check_next_ext!=0x00))) 
				  	return NOT_UTP;
			 	  else
					return UTP_RESET;
		  	}

	  case 0x41:
		    if ((check_ext == 0x00) || (check_ext == 0x02)  ) {
			  //return UTP_SYN;
				  if ((check_ext==0x02) && (!(check_next_ext!=0x00))) 
				  	return NOT_UTP;
			 	  else
					return UTP_SYN;
		  	}
		  
           default:
		  return NOT_UTP;

  }
	

}//end function




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



/**
 * <aa>TODO: check if we are compliant with the draft that says:
if the connection is idle for a given minute, no data is available for the
one-way delay and, therefore, a value of +INFINITY has to be stored
in the list. If the connection has been idle for BASE_HISTORY
minutes, all minima in the list are thus set to +INFINITY and
measurement begins anew. LEDBAT thus requires that during idle
periods, an implementation must maintain the base delay list.
</aa>
*/
/**
 * <aa>see section 3.4.2 of "Low Extra Delay Background Transport (LEDBAT)
 * draft-ietf-ledbat-congestion-10.txt"</aa>
 */
void update_delay_base(u_int32_t time_diff,u_int32_t time_ms, ucb *thisdir){
	/*inizializzazione */
	int j=0;
	while ( j<DELAY_BASE_HISTORY ){
		if (thisdir->utp.delay_base_hist[j]==0) thisdir->utp.delay_base_hist[j]=time_diff;
		j++;
		//thisdir->utp.delay_base=time_diff;
	}

	//<aa>In ordinary cases, thisdir->utp.last_update < time_ms
	//(the timestamp of the present packet is greater than the one of the
	//last packet used to update the baseline). When an out-of-order packet
	//arrives, this inequality does not hold. In this case, we do not update
	//</aa>

	
	if ( 	wrapping_compare_less( thisdir->utp.last_update, time_ms)  &&  

		//<aa>we update the delay_base every minute</aa>
		wrapping_compare_less( 60*1000*1000, (time_ms - thisdir->utp.last_update))
	){
		// <aa>"LEDBAT sender stores BASE_HISTORY separate minima---one each for the
		// last BASE_HISTORY-1 minutes, and one for the running current minute.
		// At the end of the current minute, the window moves---the earliest
		// minimum is dropped and the latest minimum is added."
		// </aa>

		//<aa>It corresponds to the "last_rollover" in the draft</aa>
		thisdir->utp.last_update=time_ms;
		
		int i=1; //rollover della lista di base_delay
		while ( i<DELAY_BASE_HISTORY ){
			thisdir->utp.delay_base_hist[i-1]=thisdir->utp.delay_base_hist[i];
			i++;
		}
		thisdir->utp.delay_base_hist[DELAY_BASE_HISTORY-1]=time_diff;
	
	}else{ //update the tail
		if (wrapping_compare_less(time_diff,thisdir->utp.delay_base_hist[DELAY_BASE_HISTORY-1]))  
			thisdir->utp.delay_base_hist[DELAY_BASE_HISTORY-1]=time_diff;
			//<aa>according to the draft, we calculate the one-way delay minima over a
			//one-minute interval</aa>
	}

   	//collect last CUR_DELAY_SIZE queueing delay 
	thisdir->utp.delay_base=min_delay_base (thisdir);

	//<aa>estimated queueing delay for the current packet</aa>
	u_int32_t delay= time_diff - thisdir->utp.delay_base;

	//<aa>The following two lines correspond to update_current_delay(...) in 
	//section 3.4.2 of [ledbat_draft]</aa>
	// <aa>CRITICAL: [ledbat_draft] sec 3.4.2 says that update_current_delay(...)
	// mantains a list of one-way delays, whereas we mantain a list of estimated queueing delays.
	// Maybe it is not correct</aa>
	thisdir->utp.cur_delay_hist[thisdir->utp.cur_delay_idx]=delay;
	thisdir->utp.cur_delay_idx= (thisdir->utp.cur_delay_idx+1)% CUR_DELAY_SIZE;
	
}

//<aa>TODO: Find a more efficient way to compute the minimum</aa>
u_int32_t min_delay_base(ucb *thisdir){
	u_int32_t min;

	min=thisdir->utp.delay_base_hist[0];	
	int i=1;
		while ( i<DELAY_BASE_HISTORY ){
			if (wrapping_compare_less(thisdir->utp.delay_base_hist[i],min)) min=thisdir->utp.delay_base_hist[i];
			i++;
		}	
	return min;
}

/**
 * <aa>
 * It returns an estimate of the current queueing delay (in microseconds).
 * 
 * sec 3.4.2 of [ledbat_draft] says that it's reasonable to calculate the queueing_dly not simply as
 * 	queueing_dly = one_way_dly - baseline
 * but "implementing FILTER() to eliminate any outliers [...] A simple MIN filter
 * applied over a small window (much smaller than BASE_HISTORY) may also
 * provide robustness to large delay peaks, as may occur with delayed ACKs in TCP"
 * Here, we implement this MIN filter.
 * </aa>
 */
u_int32_t get_queueing_delay(ucb *thisdir) {
	u_int32_t min;
	min=thisdir->utp.cur_delay_hist[0];	
	int i=1;
	while ( i<CUR_DELAY_SIZE ){
		if (	((thisdir->utp.cur_delay_hist[i]<min) && (thisdir->utp.cur_delay_hist[i]>0))
			|| (min==0)  
		)
		min=thisdir->utp.cur_delay_hist[i];
		i++;
	}

	/** 
	 * <aa>CRITICAL: if we want to implement the MIN FILTER described in [ledbat_draft] we must
	 * calculate
	 *	queue_dly_est = min(last 3 owd) - baseline
	 * On the contrary, since an element of thisdir->utp.cur_delay_hist is a queueing dly, 
	 * we are calculating
	 	  	wfprintf (fp_ledbat_logc, "%s %s ",
			HostName(pup->addr_pair.a_address), 
			ServiceName(pup->addr_pair.a_port));
* 	queue_dly_est = min(last 3 queue_dly) = min (last 3 owd - baseline)
	 * </aa>
	 */
	return min;
}





void
parser_BitTorrentUDP_packet (struct ip *pip, void *pproto, int tproto, void *pdir, 
	int dir, void *hdr, void *plast, int type_utp)
{

    	void *theheader;
	utp_hdr *putp = (struct utp_hdr *) hdr;

	theheader=((char *) pproto + 8);
	struct udphdr *pudp =  pproto;
	
	u_int16_t putplen=(ntohs(pudp->uh_ulen) -8); //payload udp len -> utp packet lenght

	// <aa>ucb is a struct which collects information about an udp 
	// connection (defined in struct.h) </aa>
	ucb *thisdir, *otherdir;

	//<aa>thisdir is a structure conveying info about the pair of nodes communicating </aa>
    	thisdir = ( ucb *) pdir;
	//<aa>putp is the pointer to the utp header of the packet in question</aa>
 	//<aa>thisdir->pup (of type "struct sudp_pair") conveys other generic info about the pair of nodes involved</aa>
	
	//<aa>Retrieve info about the other direction (opposite to the direction of this packet)</aa>
	otherdir = (dir == C2S) ? &(thisdir->pup->s2c) : &(thisdir->pup->c2s);
	//<aa>Now, otherdir conveys info about the opposite direction</aa>

	//<aa>
	#ifdef SEVERE_DEBUG
	if (dir!=C2S && dir!=S2C){
		printf("\ndir=%d\n", dir); exit(5454512);
	}
	
	if (thisdir->dir==0){
		//This is the first packet seen on this direction
		thisdir->dir =dir;
		otherdir->dir = (dir == C2S) ? S2C: C2S;
	}
	#endif
	//</aa>


	//some statistics
	((ucb *) pdir)->utp.pkt_type_num[type_utp-1]++; //count the number of packets of a given type 
	//note: we consider type_utp for type of the packet, not type field in the packet
	thisdir->utp.total_pkt++;
	thisdir->utp.bytes+=putplen;

	if (type_utp==UTP_DATA)	{
		thisdir->utp.data_pktsize_sum+=putplen;
		
		if ((thisdir->utp.data_pktsize_max==0) || (thisdir->utp.data_pktsize_max<putplen))
			thisdir->utp.data_pktsize_max=putplen;

		if ((thisdir->utp.data_pktsize_min==0) || (thisdir->utp.data_pktsize_min>putplen))
			thisdir->utp.data_pktsize_min=putplen;
	}

	udp_pair *pup, *pup1;
 	pup = thisdir->pup;
	pup1= otherdir->pup;

	//<aa>
	#ifdef SEVERE_DEBUG
	check_direction_consistency(thisdir, __LINE__);
	#endif	//</aa>

#ifdef LEDBAT_DEBUG	
		//1 IP Source
		//2 Port Source
		//3 IP Dest
		//4 Port Dest
		//5 Length UTP Packet (header UTP + payload)
		fprintf(fp_stdout," %s ",HostName(*IPV4ADDR2ADDR (&pip->ip_src)));
		fprintf(fp_stdout," %d ", ntohs(pudp->uh_sport));
	
		fprintf(fp_stdout," %s", HostName(*IPV4ADDR2ADDR (&pip->ip_dst)));
		fprintf(fp_stdout," %d %d", ntohs(pudp->uh_dport),putplen);
	  
    	
		//6 Version UTP
		//7 Type UTP
		//8 Extension UTP
		  wfprintf (fp_ledbat_logc, "%s %s ",
			HostName(pup->addr_pair.a_address), 
			ServiceName(pup->addr_pair.a_port));
	fprintf(fp_stdout," %d %d %d",(putp->ver), 			                    
		(putp->type),(putp->ext));
	
		//9 Connection ID
		//10 Sequence Number
		  wfprintf (fp_ledbat_logc, "%s %s ",
			HostName(pup->addr_pair.a_address), 
			ServiceName(pup->addr_pair.a_port));
	//11 Ack Number
		fprintf(fp_stdout," %d %d %d",ntohs(putp->conn_id), 			                    
		ntohs(putp->seq_nr),ntohs(putp->ack_nr));	
	
		//<aa>putp is the pointer to the utp header of the packet in question</aa>

		//12 Timestamp Microsecond
		//13 Timestamp Diff
		//14 Wnd_size
		fprintf(fp_stdout," %u %u %u",ntohl(putp->time_ms), 	           
		ntohl(putp->time_diff),ntohl(putp->wnd_size));
#endif
	


	update_delay_base(ntohl(putp->time_diff), ntohl(putp->time_ms), thisdir);
	
	float estimated_qdF=(float)get_queueing_delay(thisdir);

	//<aa>TODO:Why calling two times the same function?</aa>
	u_int32_t estimated_qdI=get_queueing_delay(thisdir);



	//to avoid overfitting, we neglect multiple consecutive equal queueing delay samples 
	if (( 	(type_utp==UTP_STATE_ACK) || (type_utp==UTP_STATE_SACK) ) || 
		( 
			(type_utp==UTP_DATA) && 
			(putp->time_diff!=thisdir->utp.last_measured_time_diff) 
		) || (estimated_qdF<120000) 
	){
		//<aa>At first, see if a window can be closed (not including the present pkt)
                float qd_w1 = windowed_queueing_delay(
			thisdir, ntohl(putp->time_ms) , estimated_qdF);
		//</aa>

		//<aa>Then, update all quantities related to the open window</aa>
		//<aa>TODO: check what 
		if (type_utp==UTP_DATA)
			thisdir->utp.last_measured_time_diff=putp->time_diff;
	
		float ewma; //Exponentially-Weighted Moving Average
		//update statistics on queueing delay in ms 
		thisdir->utp.qd_measured_count++;
		thisdir->utp.qd_measured_sum+= (estimated_qdF/1000);
		thisdir->utp.qd_measured_sum2+= ((estimated_qdF/1000)*(estimated_qdF/1000));

       	  	wfprintf (fp_ledbat_logc, "%s %s ",
			HostName(pup->addr_pair.a_address), 
			ServiceName(pup->addr_pair.a_port));
       		if (thisdir->utp.ewma>0) {
                   ewma=thisdir->utp.ewma;
                   thisdir->utp.ewma = alpha*(estimated_qdF/1000) + (1-alpha)*ewma;
		}else
		   thisdir->utp.ewma = estimated_qdF/1000;
  		       
#ifdef LEDBAT_DEBUG	
			//15 Base_delay
       		 	//16 Queuing_delay float in ms
        		//17 Queuing_delay integer in ms - millisecond
        		//18 lastupdate
			//19 ewma
        		fprintf(fp_stdout," %u %f %u ",thisdir->utp.delay_base, estimated_qdF/1000, estimated_qdI/1000 );
       		 	fprintf(fp_stdout," %u ",thisdir->utp.last_update);
			fprintf(fp_stdout," %f ",thisdir->utp.ewma);

 #endif
		  wfprintf (fp_ledbat_logc, "%s %s ",
			HostName(pup->addr_pair.a_address), 
			ServiceName(pup->addr_pair.a_port));
	
		//utp-tma13 
		/** <aa>The following instruction has been moved up</aa>
                float qd_w1 =
			windowed_queueing_delay(thisdir, ntohl(putp->time_ms) , estimated_qdF);
		*/
		
		// <aa>???: Why do we calculate estimated_qdF in microseconds and 
		// queueing_delay_max in milliseconds? </aa>
		if ((thisdir->utp.queueing_delay_max < (estimated_qdF/1000)))
			thisdir->utp.queueing_delay_max= (estimated_qdF/1000);

		// <aa>???: Why do we calculate estimated_qdF in microseconds and 
		// queueing_delay_min in milliseconds? </aa>
		if ((thisdir->utp.queueing_delay_min > (estimated_qdF/1000)))
			thisdir->utp.queueing_delay_min= (estimated_qdF/1000);
		
		float estimated_99P;
		float estimated_95P;
		float estimated_90P;
		float estimated_75P;

		if (qd_w1!=-1){
		  	wfprintf (fp_ledbat_logc, "%s %s ",
			HostName(pup->addr_pair.a_address), 
			ServiceName(pup->addr_pair.a_port));
			estimated_99P=PSquare(thisdir, (int)qd_w1, PERC_99);
			estimated_95P=PSquare(thisdir, (int)qd_w1, PERC_95);
			estimated_90P=PSquare(thisdir, (int)qd_w1, PERC_90);
			estimated_75P=PSquare(thisdir, (int)qd_w1, PERC_75);
		}

	

		#ifdef LEDBAT_DEBUG
		//35 estimated_99percentile(w1) 36 estimated_95percentile(w1) 37 estimated_90percentile(w1) 38 estimated_75percentile(w1) 
		  wfprintf (fp_ledbat_logc, "%s %s ",
			HostName(pup->addr_pair.a_address), 
			ServiceName(pup->addr_pair.a_port));
		fprintf(fp_stdout," %f %f %f %f ", estimated_99P, estimated_95P,  estimated_90P, estimated_75P );
		#endif
	}
	else
	{
		//15 -16 -17 -18 -19  ....29....34 35 36 37 38
		
		#ifdef LEDBAT_DEBUG
			fprintf(fp_stdout, " - - - - - - - - - - - - - - - - - - - - - - - - " );
		#endif
	}
	
	/*start of bittorrent message*/
	u_int8_t *pputp=NULL;
	u_int8_t *extchain=NULL;
	u_int8_t len;
	if (putp->ext == 0) {
	   pputp=((u_int8_t *) putp) + 20;
	 	  	wfprintf (fp_ledbat_logc, "%s %s ",
			HostName(pup->addr_pair.a_address), 
			ServiceName(pup->addr_pair.a_port));
  
	   #ifdef LEDBAT_DEBUG
	   	//37 No exentsion 
	   	//38 No length extension 
	   	fprintf(fp_stdout, " - -");
	   #endif

	   }
	else{
	   extchain=((u_int8_t *) theheader) + 20;
	   
	   len=0; 
           do {
	   
	   	extchain=extchain + len;
		len=*(extchain+1) + 2 ;
		//printf("\n len %d", len);
		#ifdef LEDBAT_DEBUG
			//37 extension
			//38 extension length
			fprintf(fp_stdout, " %d %d",*extchain, (len-2));
		#endif			
	   
	   } while ( *extchain != 0 );
	   
		  	wfprintf (fp_ledbat_logc, "%s %s ",
			HostName(pup->addr_pair.a_address), 
			ServiceName(pup->addr_pair.a_port));
   extchain=extchain + len;
	   pputp=extchain;
	}
	
	
	if (((u_long) pputp - (u_long) putp) < (u_long)putplen   ) {
		#ifdef LEDBAT_DEBUG
			//39 1st bittorrent message word  
			fprintf(fp_stdout, " %u \n",ntohl(*((u_int32_t *) pputp) ));
		#endif

		/*finished uTP header: handover to BitTorrent message parser... */
		parser_BitTorrentMessages(pputp, tproto, pdir, dir, hdr, plast);


		
	}
	else {
		#ifdef LEDBAT_DEBUG
			//39 1st bittorrent message word  
			fprintf(fp_stdout, " - \n");
		#endif
	}

	
}





void BitTorrent_flow_stat (struct ip *pip, void *pproto, int tproto, void *pdir,
		 int dir, void *hdr, void *plast)
{
	int type_utp;
	if (tproto==PROTOCOL_UDP){

  		type_utp = is_utp_pkt (pip, pproto, pdir, plast);

		if (type_utp>0)   {
	      		parser_BitTorrentUDP_packet(pip,pproto,tproto,pdir,dir,hdr,plast,type_utp);
		}

	}

}//flowstat

// <aa>
#ifdef LEDBAT_WINDOW_CHECK

// <aa>: trick to print the enum inspired by:
// http://www.cs.utah.edu/~germain/PPS/Topics/C_Language/enumerated_types.html
char* udp_type_string[] = {"UDP_UNKNOWN","FIRST_RTP","FIRST_RTCP","RTP","RTCP","SKYPE_E2E",
	"SKYPE_OUT","SKYPE_SIG","P2P_EDK","P2P_KAD","P2P_KADU","P2P_GNU","P2P_BT","P2P_DC",
	"P2P_KAZAA","P2P_PPLIVE","P2P_SOPCAST","P2P_TVANTS","P2P_OKAD","DNS","P2P_UTP",
	"P2P_UTPBT","UDP_VOD","P2P_PPSTREAM","TEREDO","UDP_SIP","LAST_UDP_PROTOCOL"};
/*
udp_type udp_types[] = {UDP_UNKNOWN,FIRST_RTP,FIRST_RTCP,RTP,RTCP,SKYPE_E2E,SKYPE_OUT, SKYPE_SIG,
	P2P_EDK, P2P_KAD,P2P_KADU,P2P_GNU, P2P_BT,P2P_DC, P2P_KAZAA,P2P_PPLIVE,P2P_SOPCAST,
	P2P_TVANTS,P2P_OKAD,DNS,P2P_UTP,P2P_UTPBT,UDP_VOD,P2P_PPSTREAM,TEREDO,UDP_SIP,
	LAST_UDP_PROTOCOL};
*/
// </aa>

/**
 * Print general info about the window (info not describing a specific direction)
 * 	thisdir: the descriptor of the udp connection
 * 	time_ms: the timestamp of the packet
 * 	qd: an estimate of the queueing delay
 */
void print_last_window_general(ucb * thisdir, u_int32_t time_ms)
{
	//We need to store the addresses returned by HostName. HostName calls
	//inet_ntoa and inet_ntoa overwrites the same buffer at every call.
	sprintf(a_address, "%s", HostName(thisdir->pup->addr_pair.a_address));
	sprintf(b_address, "%s", HostName(thisdir->pup->addr_pair.b_address));

	//number of windows after the closed one that contain non samples
	//(and will be ignored)
	//<aa>TODO: This value is indicative only if time_ms is the time of the pkt in the 
	//direction dir; if, on the contrary, the packet that is triggering the window closure
	//is in the direction opposite to dir, there can be other void windows in the direction
	//dir</aa>
	unsigned int following_void_windows = (time_ms - thisdir->utp.time_zero_w1)/1000000;
	
	//<aa>TODO: maybe some of the following info describes a specidic direction rather than
	// one. Check it</aa>

	wfprintf(fp_ledbat_window_logc,"%d 0x%X 0x%X %u %u %u %s %hu %s %hu ",
		thisdir->uTP_conn_id,			//1
		thisdir->utp.peerID,			//2
		thisdir->utp.infoHASH,			//3
		thisdir->utp.time_zero_w1,		//4
	        time_ms,				//5
		following_void_windows,			//6
		a_address,				//7
		thisdir->pup->addr_pair.a_port,		//8
		b_address,				//9
		thisdir->pup->addr_pair.b_port		//10
	);
}

/**
 * Print info for a specific direction
 * 	thisdir: the descriptor of the udp connection
 * 	qd_window: queueing delay of the window (-1 if this window has non samples)
 */
void print_last_window_directional(ucb * thisdir,
	float qd_window, float window_error, int window_size)
{
	#ifdef SEVERE_DEBUG
	if (thisdir->dir != C2S && thisdir->dir != S2C ){
		printf("\nledbat.c %d: thisdir->dir=%d\n", __LINE__, thisdir->dir);
		exit(741);
	}
	#endif

	wfprintf(fp_ledbat_window_logc, " %s %d", 
		udp_type_string[thisdir->type],		//11-25
		thisdir->dir				//12-26
	);

	if (qd_window == NOSAMPLES)
		wfprintf(fp_ledbat_window_logc, " - -");
	else
		wfprintf(fp_ledbat_window_logc, " %f %f", 
			qd_window,			//13-27
			window_error			//14-28
		);

	wfprintf(fp_ledbat_window_logc," %f %d %d %d %d %d %f %f %f %u",
		thisdir->utp.qd_max_w1,			//15-29
		(int)((int)qd_window/(window_size*1000)),//16-30
		thisdir->utp.qd_count_w1, //window_no.	//17-31
		thisdir->utp.qd_measured_count,		//18-32
		thisdir->utp.qd_measured_count- thisdir->utp.qd_count_w1,//no_of_pkts_in_windows
		thisdir->utp.qd_measured_count_w1,	//20-34: no of not void windows
		thisdir->utp.qd_measured_sum,		//21-35
		thisdir->utp.qd_measured_sum_w1,	//22-36
		thisdir->utp.qd_sum_w1,			//23-37
		thisdir->utp.delay_base			//24-38
	);
}

// </aa>
#endif

void print_BitTorrentUDP_conn_stats (void *thisflow, int tproto){
	
  ucb *thisUdir,*thisC2S,*thisS2C;
  udp_pair *pup;
  udp_pair * thisflow1 = (udp_pair *)thisflow;
  struct utp_stat utpstat;
  
  if (tproto == PROTOCOL_TCP)
    return;

  thisC2S = &(thisflow1->c2s);
  thisS2C = &(thisflow1->s2c);
  

    if ((thisC2S->is_uTP) && (thisS2C->is_uTP)) {


      	  thisUdir = thisC2S;
      	  pup = thisUdir->pup;
      	  utpstat = thisUdir->utp;
	  
	  if (utpstat.pkt_type_num[UTP_DATA-1]>0)
	  	utpstat.data_pktsize_average=utpstat.data_pktsize_sum/utpstat.pkt_type_num[UTP_DATA-1];
	  else
		utpstat.data_pktsize_average=0;


#ifdef DEBUG_LEDBAT		
// per-packet sampling introduce bias !
// windowed statistics more robusts (TMA'13)
// 	  if (utpstat.qd_measured_count>0) {
// 	      utpstat.queueing_delay_average =
// 			 utpstat.qd_measured_sum/utpstat.qd_measured_count;
// 	      int N=utpstat.qd_measured_count;
//  	      utpstat.queueing_delay_standev =
// 		    Stdev(utpstat.qd_measured_sum,utpstat.qd_measured_sum2,N);		  
// 	  }
// 	  else {		  
// 		utpstat.quelog_engine && fp_ledbat_logcuing_delay_average=0;
// 		utpstat.queueing_delay_standev=0;
// 	  }
#endif  	

  	 //w=1
	  if (utpstat.qd_measured_count_w1>0) {
                		
		utpstat.queueing_delay_average_w1 = 
			utpstat.qd_measured_sum_w1/utpstat.qd_measured_count_w1;

		int N=utpstat.qd_measured_count_w1;
           
		utpstat.queueing_delay_standev_w1 =Stdev(
			utpstat.qd_measured_sum_w1,utpstat.qd_measured_sum2_w1,N );

          }
          else {
                utpstat.queueing_delay_average_w1=0;
                utpstat.queueing_delay_standev_w1=0;
          }

	
	 utpstat.P[PERC_99]=utpstat.y_P[2][PERC_99];
	 utpstat.P[PERC_95]=utpstat.y_P[2][PERC_95];
	 utpstat.P[PERC_90]=utpstat.y_P[2][PERC_90];
	 utpstat.P[PERC_75]=utpstat.y_P[2][PERC_75];

	 if (log_engine && fp_ledbat_logc!=NULL){
 
  		//     #   Field Meaning
  		//    ----log_engine && fp_ledbat_logc----------------------------------
 		//     Source Address
		//     Source Port		
	    	//     time of first packet seen 
 	    	//     #pkts
	 	//     #bytes
	  	//     datapkt size min
	 	//     datapkt size max
	    	//     datapkt size ave
	 	//     #data-pkts
	    	//     #fin-pkts 
	 	//     #state-ack-pkts
	    	//     #state-sack-pkts 
	 	//     #reset-pkts
	    	//     #syn-pkts 
	 	//     qd log_engine && fp_ledbat_logcmin
	  	//     qd max
	  	//     qd average (w=1)	
		//     qd standard deviation (w=1)
		//     75th percentile
		//     90th percentile  
		//     95th percentile
		//     99th percentile
	  	//     PeerID
		//     infoHASH
	 
	  	wfprintf (fp_ledbat_logc, "%s %s ",
			HostName(pup->addr_pair.a_address), 
			ServiceName(pup->addr_pair.a_port));
	 	wfprintf(fp_ledbat_logc,"%f %d %d %d %d %f %d %d %d %d %d %d ", 
			time2double (thisUdir->first_pkt_time)/1000.0,
	     		utpstat.total_pkt,
	     		utpstat.bytes,
	     		utpstat.data_pktsize_min,
	     		utpstat.data_pktsize_max,
	     		utpstat.data_pktsize_average,
  	     		utpstat.pkt_type_num[UTP_DATA-1],
  	     		utpstat.pkt_type_num[UTP_FIN-1] ,
  	     		utpstat.pkt_type_num[UTP_STATE_ACK-1],
  	     		utpstat.pkt_type_num[UTP_STATE_SACK-1],
	     		utpstat.pkt_type_num[UTP_RESET-1] ,
	     		utpstat.pkt_type_num[UTP_SYN-1]);
		wfprintf(fp_ledbat_logc, "%f %f %f %f %f %f %f %f ",
  	   		utpstat.queueing_delay_min,
	     		utpstat.queueing_delay_max,
	    		utpstat.queueing_delay_average_w1,
	     		utpstat.queueing_delay_standev_w1,
			utpstat.P[PERC_75],
			utpstat.P[PERC_90], 
			utpstat.P[PERC_95], 
			utpstat.P[PERC_99]);

//araldo!!
/*
		printf(fp_ledbat_logc, " 0x%X 0x%X\n",
		     	strlen(utpstat.peerID)>0 ? utpstat.peerID : " ---- ",    
		     	strlen(utpstat.infoHASH)>0 ? utpstat.infoHASH : " ---- " );
*/	}//if log_engineu


  	  thisUdir = thisS2C;
 	  pup = thisUdir->pup;
	  utpstat = thisUdir->utp;

	
	  if (utpstat.pkt_type_num[UTP_DATA-1]>0)
	  	utpstat.data_pktsize_average=
		utpstat.data_pktsize_sum/utpstat.pkt_type_num[UTP_DATA-1];
	  else 
		utpstat.data_pktsize_average=0;


	  //w=1
          if (utpstat.qd_measured_count_w1>0) {
               	utpstat.queueing_delay_average_w1=
			utpstat.qd_measured_sum_w1/utpstat.qd_measured_count_w1;
                int N=utpstat.qd_measured_count_w1;
		utpstat.queueing_delay_standev_w1=
		Stdev(utpstat.qd_measured_sum_w1,utpstat.qd_measured_sum2_w1,N );

          }
          else {
                utpstat.queueing_delay_average_w1=0;
                utpstat.queueing_delay_standev_w1=0;
          }


		
	 utpstat.P[PERC_99]=utpstat.y_P[2][PERC_99];
	 utpstat.P[PERC_95]=utpstat.y_P[2][PERC_95];
	 utpstat.P[PERC_90]=utpstat.y_P[2][PERC_90];
	 utpstat.P[PERC_75]=utpstat.y_P[2][PERC_75];

	 if (log_engine && fp_ledbat_logc!=NULL){

		//     #   Field Meaning 
 		//    --------------------------------------
 		//     Source Address
		//     Source Port
	    	//     time of first packet seen 
 	    	//     #pkts
	 	//     #bytes
	  	//     datapkt size min
	 	//     datapkt size max
	    	//     datapkt size ave
	 	//     #data-pkts
	    	//     #fin-pkts 
	 	//     #state-ack-pkts
	    	//     #state-sack-pkts 
	 	//     #reset-pkts
	    	//     #syn-pkts 
	 	//     qd min
	  	//     qd max
	  	//     qd average (w=1)
	  	//     qd standard deviation (w=1)
		//     75th percentile
		//     90th percentile  
		//     95th percentile
		//     99th percentile
	  	//     PeerID
		//     infoHASH
	
	  	wfprintf (fp_ledbat_logc, "%s %s ",
			HostName(pup->addr_pair.b_address), 
			ServiceName(pup->addr_pair.b_port));
	 	wfprintf(fp_ledbat_logc,"%f %d %d %d %d %f %d %d %d %d %d %d ", 
			time2double (thisUdir->first_pkt_time)/1000.0,
	     		utpstat.total_pkt,
	     		utpstat.bytes,
	     		utpstat.data_pktsize_min,
	     		utpstat.data_pktsize_max,
	     		utpstat.data_pktsize_average,
  	     		utpstat.pkt_type_num[UTP_DATA-1],
  	     		utpstat.pkt_type_num[UTP_FIN-1] ,
  	     		utpstat.pkt_type_num[UTP_STATE_ACK-1],
  	     		utpstat.pkt_type_num[UTP_STATE_SACK-1],
	     		utpstat.pkt_type_num[UTP_RESET-1] ,
	     		utpstat.pkt_type_num[UTP_SYN-1]);
		wfprintf(fp_ledbat_logc, "%f %f %f %f %f %f %f %f ",
  	   		utpstat.queueing_delay_min,
	     		utpstat.queueing_delay_max,
	    		utpstat.queueing_delay_average_w1,
	     		utpstat.queueing_delay_standev_w1,
			utpstat.P[PERC_75],
			utpstat.P[PERC_90], 
			utpstat.P[PERC_95], 
			utpstat.P[PERC_99]);

//araldo!!			
		wfprintf(fp_ledbat_logc, "0x%X 0x%X ",
	     		strlen(utpstat.peerID)>0 ? utpstat.peerID : "----",    				     	strlen(utpstat.infoHASH)>0 ? utpstat.infoHASH : "----");
          }//if log_engine
          wfprintf (fp_ledbat_logc,"\n");
  }


}

//<aa>
float windowed_queueing_delay( void *pdir, u_int32_t time_ms, float qd )
{
	//time_ms is in microsecond (10^-6)
	//qd/1000 is in ms
	//window in ms 

	float qd_window;
	float return_val=-1;
	
	ucb *thisdir;
	thisdir = ( ucb *) pdir;

	#ifdef SEVERE_DEBUG
	check_direction_consistency(thisdir, __LINE__);
	if(time_ms - thisdir->utp.time_zero_w1 < 0){
		printf("\nledbat.c %d: ERROR:time_ms=%d, thisdir->utp.time_zero_w1=%d\n",
			__LINE__,time_ms, thisdir->utp.time_zero_w1);
		exit(7);
	}
	#endif

	ucb* otherdir = (thisdir->dir == C2S) ? &(thisdir->pup->s2c) : &(thisdir->pup->c2s);

	//initialize time_zero
	//<aa>TODO: better if we have a single time_zero_w1
	if (thisdir->utp.time_zero_w1==0){
		//Remember: check_direction_consistency(...) guarantees that if in this
		//direction time_zero_w1==0, then also in the opposite direction 
		//utp.time_zero_w1==0
		thisdir->utp.time_zero_w1=time_ms;
		otherdir->utp.time_zero_w1=time_ms;
	}

	if ( (time_ms - thisdir->utp.time_zero_w1) >= 1000000)
	{
		#ifdef LEDBAT_WINDOW_CHECK
		print_last_window_general(thisdir, time_ms);
		#endif
		float other_qd_window;
		if (thisdir->dir==C2S){
			qd_window = close_window(thisdir, time_ms);
			other_qd_window = close_window(otherdir, time_ms);
		}else{
			other_qd_window = close_window(otherdir, time_ms);
			qd_window = close_window(thisdir, time_ms);
		}
		wfprintf(fp_ledbat_window_logc,"\n");

		#ifdef SEVERE_DEBUG
		if (qd_window == -1 && other_qd_window ==-1){
			printf("\nledbat.c %d:ERROR: No pkts in both direction\n",__LINE__);
			exit(987324);
		}
		#endif
		return_val = qd_window;
	}

	#ifdef SEVERE_DEBUG
	check_direction_consistency(thisdir, __LINE__);
	#endif

	//<aa>Update the max
	//TODO: why expressing qd in microseconds and qd_max_w1 in milliseconds?</aa>
	if (qd/1000 >= thisdir->utp.qd_max_w1)
		thisdir->utp.qd_max_w1=qd/1000;

   return return_val;
}//windowed
//</aa>

/*
float windowed_queueing_delay( void *pdir, u_int32_t time_ms, float qd )
{
	//time_ms is in microsecond (10^-6)
	//qd/1000 is in ms
	//window in ms 

	float qd_window;
	float window_error;
	float res=-1;
	int window_size = 1;

	ucb *thisdir;
	thisdir = ( ucb *) pdir;

	#ifdef SEVERE_DEBUG
	check_direction_consistency(thisdir);
	#endif

	//initialize time_zero
	if (thisdir->utp.time_zero_w1==0)
		thisdir->utp.time_zero_w1=time_ms;

	//<aa>TODO: why expressing qd in microseconds and qd_max_w1 in milliseconds?</aa>
	if (qd/1000 >= thisdir->utp.qd_max_w1)
		thisdir->utp.qd_max_w1=qd/1000;
	
	u_int32_t actual_win_size = time_ms - thisdir->utp.time_zero_w1;

	if ( (time_ms - thisdir->utp.time_zero_w1) >= 1000000)
	{
	 	// <aa>Now we can "close" the window and compute its statistics </aa>
		// <aa>CRITICAL: Suppose that the last packet (not the current one) arrived
		// less then 1s after the window opened. Suppose that the current packet arrives		// 90s after the last one. We cannot close the window with the last packet, we 
		// can close the window only after the current packet arrives. The problem is that
		// this leads to a distorted window (larger than 1 s)
		//
		// SOLUTION:
		// If the current packet arrives after a second, we can close the window, including
		// in it the last packet but not the current one. The current packet will be the
		// first of the new window
		//</aa>


		qd_window=(thisdir->utp.qd_measured_sum - thisdir->utp.qd_sum_w1)/
			(thisdir->utp.qd_measured_count- thisdir->utp.qd_count_w1);

		window_error=Stdev(thisdir->utp.qd_measured_sum - thisdir->utp.qd_sum_w1, 
		      thisdir->utp.qd_measured_sum2 - thisdir->utp.qd_sum2_w1,
		      thisdir->utp.qd_measured_count - thisdir->utp.qd_count_w1 );
		
		//<aa>
		#ifdef LEDBAT_DEBUG
		if (thisdir->utp.qd_measured_sum - thisdir->utp.qd_sum_w1 < 0){
			printf("\n\n\n\nledbat.c %d: ERROR: qd_measured_sum(%f) < qd_sum_w1(%f)\n\n\n",
				__LINE__,thisdir->utp.qd_measured_sum, thisdir->utp.qd_sum_w1);
			exit(-9987);
		}
		
		if (thisdir->utp.qd_sum_w1 < 0){
			printf("\n\n\nledbat.c %d: ERROR: qd_sum_w1(%f) < 0\n\n\n\n",
				__LINE__,thisdir->utp.qd_sum_w1);
			exit(-9911);
		}

		#endif
		//</aa>

		#ifdef LEDBAT_WINDOW_CHECK
		//araldo!!
		//  - windowed_log_engine
		//  - at most once per second
		//  - dumps IPs IPd Ps Pd E[qd] #pkts flow_classification_label
		//
		
		#ifdef SEVERE_DEBUG
		check_direction_consistency(thisdir);
		#endif

		print_last_window(thisdir, time_ms, actual_win_size, qd_window, window_error, window_size);
		#endif

		thisdir->utp.qd_sum_w1 += 
			(thisdir->utp.qd_measured_sum - thisdir->utp.qd_sum_w1);		
		thisdir->utp.qd_count_w1 += (thisdir->utp.qd_measured_count-thisdir->utp.qd_count_w1);
		thisdir->utp.qd_sum2_w1+=(thisdir->utp.qd_measured_sum2-thisdir->utp.qd_sum2_w1);

		//<aa>??? I think it is needed to correctly close the window
		thisdir->utp.time_zero_w1=time_ms;
		//</aa>

		//stqd_max_w1atistics
		thisdir->utp.qd_measured_count_w1++;
		thisdir->utp.qd_measured_sum_w1+=qd_window;
		thisdir->utp.qd_measured_sum2_w1+=((qd_window)*(qd_window));

		return qd_window;
	}
   return res;
}//windowed
*/



float PSquare (void* pdir, float q, int p ){
	ucb *thisdir;
	thisdir = ( ucb *) pdir;
	int k;
	float P;


	switch ( (int)(p) ){
		case ( PERC_99 ):
			P=0.99;
			break;

		case ( PERC_95 ):
			P=0.95;
			break;

		case ( PERC_90 ):
			P=0.90;
			break;

		case ( PERC_75 ):
			P=0.75;
			break;

		default:
			break;
	}


			thisdir->utp.N_P[p]++;
			if (thisdir->utp.N_P[p]==1){
				thisdir->utp.n_P[0][p]= 1;
				thisdir->utp.dn_P[0][p]= 0;
				thisdir->utp.n_P[1][p]=(1 +(2*P));
				thisdir->utp.dn_P[1][p]= (P/2);
				thisdir->utp.n_P[2][p]= (1 + (4*P));
				thisdir->utp.dn_P[2][p]= P;
				thisdir->utp.n_P[3][p]= (3 + (2*P));
				thisdir->utp.dn_P[3][p]= ((1+P)/2);
				thisdir->utp.n_P[4][p]= 5;
				thisdir->utp.dn_P[4][p]= 1;
//				printf("\nstart %d %f %f %f %f %f %f %f %f %f %f", thisdir->utp.N_99P, thisdir-> utp.n_99P[0], thisdir->utp.dn_99P[0] , thisdir-> utp.n_99P[1], thisdir->utp.dn_99P[1],  thisdir-> utp.n_99P[2], thisdir->utp.dn_99P[2],  thisdir-> utp.n_99P[3], thisdir->utp.dn_99P[3] , thisdir-> utp.n_99P[4], thisdir->utp.dn_99P[4] );
			}
				
			if (thisdir->utp.N_P[p]<=5){ //initialization phase
				
				thisdir->utp.y_P[ thisdir->utp.N_P[p]-1 ][p]=(int)(q);
				thisdir->utp.x_P[ thisdir->utp.N_P[p]-1 ][p]= thisdir->utp.N_P[p];
			
//				printf(" put %f in y %f ", (float)(q), thisdir->utp.y_99P[thisdir-> utp.N_99P-1] );
					
				if (thisdir->utp.N_P[p]==5){ //sort the first five samples
		//			printf("\nsort the five");
					int i=0;
					float bubble = 0;
				 	int swapped=0;

					while ((i<=4) || (swapped==1)){
						if (i==5) {
							i=0;
							swapped=0;}
						//printf("\n %d ", i);
						
						if ((thisdir->utp.y_P[i][p] > thisdir->utp.y_P[i+1][p]) && (i!=4)){
							bubble=thisdir->utp.y_P[i][p];
							thisdir->utp.y_P[i][p]=thisdir->utp.y_P[i+1][p];
							thisdir->utp.y_P[i+1][p]=bubble;
							swapped=1;
						} 
						i++;
					}
					
				}
			}
			else{
			
					//printf("\n else finalmente ");
					if (q < (thisdir->utp.y_P[0][p])){
						thisdir->utp.y_P[0][p]=q;
 						k=1; //first marker -> position 0
					}else{

						if ( (q >= (thisdir->utp.y_P[0][p])) && (q < (thisdir->utp.y_P[1][p])) ){
							k=1;	
						}else{
 
							if ( (q >= (thisdir->utp.y_P[1][p])) && (q < (thisdir->utp.y_P[2][p])) ){
								k=2;	
							}else{
					
								if ( (q >= (thisdir->utp.y_P[2][p])) && (q < (thisdir->utp.y_P[3][p])) ){
									k=3;	
								}else{
					
									if ( (q >= (thisdir->utp.y_P[3][p])) && (q < (thisdir->utp.y_P[4][p])) ){
										k=4;	
									}else{
 
										if ( q > (thisdir->utp.y_P[4][p]) ){
											thisdir->utp.y_P[4][p]=q;
										k=4;
					}}}}}}
				//printf("\n k is %d  ", k);
						
				

				int i=0;
				while ( i < 5){
					thisdir->utp.n_P[i][p]= thisdir->utp.n_P[i][p]+ thisdir->utp.dn_P[i][p];
					
					i++;
				}//update positions of markers
			

  //                              printf("\n before x[0  1  2  3  4 ] %f %f %f %f %f", thisdir->utp.x_99P[0], thisdir->utp.x_99P[1], thisdir->utp.x_99P[2], thisdir->utp.x_99P[3], thisdir->utp.x_99P[4] );
	
				int j;
				j=k;
				while ( j< 5){	
					thisdir->utp.x_P[j][p]++;
					j++;
				}
			

//				printf("\n now n[0  1  2  3  4 ] %f %f %f %f %f", thisdir->utp.n_99P[0], thisdir->utp.n_99P[1], thisdir->utp.n_99P[2], thisdir->utp.n_99P[3], thisdir->utp.n_99P[4] );
//				printf("\n after x[0  1  2  3  4 ] %f %f %f %f %f", thisdir->utp.x_99P[0], thisdir->utp.x_99P[1], thisdir->utp.x_99P[2], thisdir->utp.x_99P[3], thisdir->utp.x_99P[4] );
//				printf("\n now y[0  1  2  3  4 ] %f %f %f %f %f", thisdir->utp.y_99P[0], thisdir->utp.y_99P[1], thisdir->utp.y_99P[2], thisdir->utp.y_99P[3], thisdir->utp.y_99P[4] );


				//adjust heights
				i=1; //1
				float dd, ni, xi, xii, ix, yi, yii, iy;
				float yp2;
				float d;
				while ( i<=3 ){
//					 \n check markers");
					ix=thisdir->utp.x_P[i-1][p];
					xi=thisdir->utp.x_P[i][p];
					xii=thisdir->utp.x_P[i+1][p];
			
					iy=thisdir->utp.y_P[i-1][p];
					yi=thisdir->utp.y_P[i][p];
					yii=thisdir->utp.y_P[i+1][p];
					
	
					ni = thisdir->utp.n_P[i][p];

					dd = ni - xi; 			
					
				        //d =(dd>0)?(1):(-1);
				        if (dd>=0) d=1;
					else d=-1; 	
						
  //                                     printf("\n i %d, ix %f, xi %f, xii %f, iy %f, yi %f, yii %f, ni %f, dd %f d %f", i, ix, xi ,xii, iy,yi,yii,ni,dd,d);	
					if (( (dd >= 1) && ((xii-xi)> 1) ) || ( (dd <= (-1)) && ((ix-xi)<(-1)))){
//						printf("\n adjust");
						//P2 formula
						yp2 = (int)(yi + (d/(xii - ix ))*(  (( xi - ix + d )*( yii - yi )/( xii - xi )) + (( xii- xi - d )*( yi - iy )/( xi - ix))  ));		
//						printf(" ,P2 formula %f, ", yp2);

						thisdir->utp.y_P[i][p]=yp2;

						if ( ( iy > yp2 )  || (  yp2 > yii) ) {

							if (d==1)
								thisdir->utp.y_P[i][p]=(int)(yi + d*( yii - yi )/( xii - xi));
			
							if (d==(-1)) 
								thisdir->utp.y_P[i][p]=(int)(yi + d*( iy-yi )/( ix -xi )   );

//							printf("\n not accept the P2formula, so linear prediction %f , d %f, yi %f, iy %f,  yii %f 	\n", thisdir->utp.y_99P[i], d, yi, iy, yii);
			 
						} 
						thisdir->utp.x_P[i][p]=xi+d;

					}//end if					

				

					i++;
				}//while
			
			}//else
			//printf("\n %f %f %f %f %f ", thisdir->utp.y_95P[0], thisdir->utp.y_95P[1], thisdir->utp.y_95P[2], thisdir->utp.y_95P[3], thisdir->utp.y_95P[4] );
	return (thisdir->utp.y_P[2][p]);
}


/* this will be called by the plugin Bittorrent*/
void
make_BitTorrent_conn_stats (void *thisflow, int tproto)
{
	print_BitTorrentUDP_conn_stats(thisflow, tproto);   
}

//<aa>
#ifdef SEVERE_DEBUG
void check_direction_consistency(ucb* thisdir, int call_line_number){
	if (thisdir->dir != C2S && thisdir->dir != S2C){
		printf("\ncheck_direction_consistency called in line %d\n", call_line_number);
		printf("\nledbat.c %d: thisdir->dir=%d\n",__LINE__,thisdir->dir); 
		exit(8787);
	}
	ucb* otherdir = (thisdir->dir == C2S) ? &(thisdir->pup->s2c) : &(thisdir->pup->c2s);
	if (otherdir->dir != (thisdir->dir == C2S ? S2C:C2S) ){
		printf("\ncheck_direction_consistency called in line %d\n", call_line_number);
		printf("\nledbat.c %d: thisdir->dir=%d, other->dir=%d\n",
			__LINE__,thisdir->dir, otherdir->dir);
		exit(9898);
	}

	if (thisdir->utp.time_zero_w1 != otherdir->utp.time_zero_w1){
		printf("\ncheck_direction_consistency called in line %d\n", call_line_number);
		printf("\nledbat.c %d: thisdir->utp.time_zero_w1=%u, otherdir->utp.time_zero_w1=%u\n",
			__LINE__,thisdir->utp.time_zero_w1, otherdir->utp.time_zero_w1);
		exit(1000);
	}
	
	if (thisdir->pup != otherdir->pup){
		printf("\ncheck_direction_consistency called in line %d\n", call_line_number);
		printf("\nledbat.c %d: Different pups\n", __LINE__);exit(21212);
	}

}
#endif
//</aa>


//<aa>
float close_window(void* dir_, u_int32_t time_ms)
{
	ucb* dir = (ucb*) dir_;
	float qd_window;
	float window_error;
	int window_size = 1;

	//number of packets in the window we are going to close (not including the last packet)
	int pkts_in_win = dir->utp.qd_measured_count- dir->utp.qd_count_w1;
	if (pkts_in_win == 0){
		//No pkts have been seen in this direction in the previous window ==> 
		// the only value to be updated is the time_zero (left_edge)

		#ifdef SEVERE_DEBUG
		if (	dir->utp.qd_measured_sum - dir->utp.qd_sum_w1 != 0 ||
			dir->utp.qd_measured_sum2 - dir->utp.qd_sum2_w1 != 0
		){
			printf("\nledbat.c %d: ERROR: if there are non pkts, values can not change\n",
				__LINE__);
			exit(46);
		}
		#endif

		#ifdef LEDBAT_WINDOW_CHECK
		print_last_window_directional(dir, NOSAMPLES, NOSAMPLES, window_size);
		#endif
		update_following_left_edge(dir, time_ms);
		return -1;
	}



		qd_window=(dir->utp.qd_measured_sum - dir->utp.qd_sum_w1)/pkts_in_win;

		window_error=Stdev(dir->utp.qd_measured_sum - dir->utp.qd_sum_w1, 
		      dir->utp.qd_measured_sum2 - dir->utp.qd_sum2_w1,
		      dir->utp.qd_measured_count - dir->utp.qd_count_w1 );
		
		//<aa>
		#ifdef SEVERE_DEBUG
		if (dir->utp.qd_measured_sum - dir->utp.qd_sum_w1 < 0){
			printf("\n\n\n\nledbat.c %d: ERROR: qd_measured_sum(%f) < qd_sum_w1(%f)\n\n\n",
				__LINE__,dir->utp.qd_measured_sum, dir->utp.qd_sum_w1);
			exit(-9987);
		}
		
		if (dir->utp.qd_sum_w1 < 0){
			printf("\n\n\nledbat.c %d: ERROR: qd_sum_w1(%f) < 0\n\n\n\n",
				__LINE__,dir->utp.qd_sum_w1);
			exit(-9911);
		}
		#endif
		//</aa>

		#ifdef LEDBAT_WINDOW_CHECK
		print_last_window_directional(dir, qd_window, window_error, window_size);
		#endif

		dir->utp.qd_sum_w1 += 
			(dir->utp.qd_measured_sum - dir->utp.qd_sum_w1);		
		dir->utp.qd_count_w1 += (dir->utp.qd_measured_count-dir->utp.qd_count_w1);
		dir->utp.qd_sum2_w1+=(dir->utp.qd_measured_sum2-dir->utp.qd_sum2_w1);

		update_following_left_edge(dir, time_ms);

		//stqd_max_w1atistics
		dir->utp.qd_measured_count_w1++;
		dir->utp.qd_measured_sum_w1+=qd_window;
		dir->utp.qd_measured_sum2_w1+=((qd_window)*(qd_window));

		return qd_window;
}

void update_following_left_edge(void* dir_, u_int32_t time_ms){
		ucb* dir = (ucb*) dir_;
		
		//Compute the left edge of the following not void window
		//offset is the time from the future window left edge and time_ms
		u_int32_t offset = (time_ms - dir->utp.time_zero_w1)%1000000;
		
		#ifdef SEVERE_DEBUG
		unsigned int following_void_windows = (time_ms - dir->utp.time_zero_w1)/1000000;
		
		u_int32_t old_time_zero = dir->utp.time_zero_w1;
		if (time_ms - ( dir->utp.time_zero_w1 + following_void_windows*1000000) != offset){
			printf("\nledbat.c %d: offset=%u, following_void_windows=%d, time_ms=%u, dir->utp.time_zero_w1=%u\n",
				__LINE__, offset, following_void_windows, time_ms, dir->utp.time_zero_w1);
			exit(978);
		}
		#endif

		dir->utp.time_zero_w1 = time_ms - offset;

		#ifdef SEVERE_DEBUG
		if ( (dir->utp.time_zero_w1 - old_time_zero)%1000000 != 0 ){
			printf("\nledbat.c %d: dir->utp.time_zero_w1=%u, old_time_zero=%d",
				__LINE__,dir->utp.time_zero_w1,old_time_zero);
			exit(1111);
		}
		#endif

}

//</aa>
