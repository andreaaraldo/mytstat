/*
 *
 * Copyright (c) 2006
 *      Politecnico di Torino.  All rights reserved.
		 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or12
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

/* define  if you want to see all identified pkts */
#define LEDBAT_DEBUG

extern FILE *fp_ledbat_logc;

//<aa>
#ifdef LEDBAT_WINDOW_CHECK
extern FILE *fp_ledbat_window_logc;
#endif
//</aa>


extern Bool log_engine;
extern int ledbat_window;




static int is_utp_pkt(struct ip *pip, void *pproto, void *pdir, void *plast);


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
	fprintf(fp_stdout, "\n1:ipsrc 2:portsrc 3:ipdest 4:portdest 5:uTPpkt_len 6:utP_version 7:uTP_type 8:uTP_extensions 9:uTP_connID 10:uTP_seqnum 11:uTP_acknum 12:uTP_timeMS 13:uTP_OWD 14:uTP_winsize 15:uTP_basedelay 16:uTP_queuingdelay_float[ms] 17:uTP_queuingdelay_int[ms] 18:last_update_time 19:uTP_ewma 20:qd_w1sec 21:st_dev_w1sec 22:max_qd_w1sec 23:floor(q/w)_w1sec 24:count(samples_in_w)_w1sec 25--29:w1b 30--34:w5 35:99percentile 36:95percentile 37:extensions? 38:type_ext? 39:first_word_BitTorrent_msg 40:last_pkt_time(s) 41:last_pkt_time(us) 42:current_time(s) 43:current_time(us) 44:qd_andrea\n ");
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

	//<aa>
	#ifdef SEVERE_DEBUG	
	if (dir!=S2C && dir!=C2S){
		printf("dir=%d\n", dir); exit(75);
	}
	#endif
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
 *//*
u_int32_t get_queueing_delay_vecchio(ucb *thisdir) {
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

	//
	// <aa> if we wanted to implement the MIN FILTER described in [ledbat_draft] we
	// would calculate
	//	queue_dly_est = min(last 3 owd) - baseline
	// On the contrary, since an element of thisdir->utp.cur_delay_hist is a queueing dly, 
	// we are calculating
	// 	queue_dly_est = min(last 3 queue_dly) = min (last 3 owd - baseline)
	// We verified that this does not affect the queueing delay estimation
	// </aa>
	//
	return min;
}
*/

// <aa>: trick to print the enum inspired by:
// http://www.cs.utah.edu/~germain/PPS/Topics/C_Language/enumerated_types.html
char* udp_type_string[] = {"UDP_UNKNOWN","FIRST_RTP","FIRST_RTCP","RTP","RTCP","SKYPE_E2E",
	"SKYPE_OUT","SKYPE_SIG","P2P_EDK","P2P_KAD","P2P_KADU","P2P_GNU","P2P_BT","P2P_DC",
	"P2P_KAZAA","P2P_PPLIVE","P2P_SOPCAST","P2P_TVANTS","P2P_OKAD","DNS","P2P_UTP",
	"P2P_UTPBT","UDP_VOD","P2P_PPSTREAM","TEREDO","UDP_SIP","LAST_UDP_PROTOCOL"};
//</aa>


void
parser_BitTorrentUDP_packet (struct ip *pip, void *pproto, int tproto, void *pdir, 
	int dir, void *hdr, void *plast, int type_utp)
{
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
	utp_stat* bufferbloat_stat = &(thisdir->utp);
	utp_stat* other_bufferbloat_stat = &(otherdir->utp);
	//</aa>


	#ifdef SEVERE_DEBUG
	check_direction_consistency(LEDBAT, DONT_CARE_TRIG, thisdir, __LINE__);
	if (thisdir == otherdir){
		printf("ledbat.c %d: thisdir == otherdir\n", __LINE__); exit(11);
	}	
	if (bufferbloat_stat == other_bufferbloat_stat){
		printf("ledbat.c %d: bufferbloat_stat == other_bufferbloat_stat\n", __LINE__); exit(11);
	}
	#endif

    	void *theheader;
	utp_hdr *putp = (struct utp_hdr *) hdr;
	Bool it_is_a_data_pkt = FALSE;

	theheader=((char *) pproto + 8);
	struct udphdr *pudp =  pproto;
	udp_pair *pup, *pup1;
 	pup = thisdir->pup;
	pup1= otherdir->pup;
	const char* type = udp_type_string[thisdir->type];
	int conn_id = thisdir->uTP_conn_id;
	Bool overfitting_avoided = FALSE;
	

	u_int16_t putplen=(ntohs(pudp->uh_ulen) -8); //payload udp len -> utp packet lenght

	//<aa>
	u_int32_t grossdelay = ntohl(putp->time_diff);
	#ifdef SEVERE_DEBUG
	if (dir!=C2S && dir!=S2C){
		printf("\ndir=%d\n", dir); exit(5454512);
	}

	check_direction_consistency(LEDBAT, DONT_CARE_TRIG, (void*)thisdir, __LINE__);
	if( elapsed(current_time,thisdir->last_pkt_time) != 0 )
	{
		printf("\nledbat.c %d: current_time=%ldsec %ldusec last_pkt_seen=%ldsec %ldusec\n",
			__LINE__,current_time.tv_sec, current_time.tv_usec, 
			thisdir->last_pkt_time.tv_sec, thisdir->last_pkt_time.tv_usec);
		exit(5646);
	}

	if (grossdelay > 1000*1000000){
		printf("\nledbat.c %d: ATTTTTTTEEEEENNNNNNZZZZZIONNNNNEEEEEEE: ERROR: time_diff is %u, more than a quarter of hour\n",
			__LINE__, grossdelay);
		printf("putp->time_diff=%X\n",putp->time_diff);
		exit(213254);
		//<aa>TODO: reactivate exit</aa>
	}
	if (elapsed(thisdir->utp.last_rollover, current_time)<=0 ){
		printf("\nledbat.c %d: \n", __LINE__); exit(849);
	}


	if (dir!=S2C && dir!=C2S) {
		printf("ledbat.c %d: ERROR: dir (%d) not valid\n",__LINE__,dir); 
		exit(7777);
	}
	if (grossdelay==0){
		printf("ledbat.c %d: ATTTTTENZZIONNNEEE: gross delay = 0\n", __LINE__); 
	}
	#endif	
	//</aa>

	//to avoid overfitting, we neglect multiple consecutive equal queueing delay samples 
	if (	( 	(type_utp==UTP_STATE_ACK) || (type_utp==UTP_STATE_SACK) )
	      ||( 
			(type_utp==UTP_DATA) && 
			(grossdelay != bufferbloat_stat->last_measured_time_diff) 
		)
	)
		overfitting_avoided = TRUE;

	if (type_utp==UTP_DATA)
		it_is_a_data_pkt = TRUE;

	bufferbloat_stat->pkt_type_num[type_utp-1]++; //count the number of packets of a given type 

	#ifdef SEVERE_DEBUG
	check_direction_consistency(LEDBAT, DONT_CARE_TRIG, pdir, __LINE__);
	#endif
		printf("Vedere quando e' il caso di chiamare chance is not valid\n");
		exit(44417899);

	if (grossdelay > 0){
		float windowed_qd = bufferbloat_analysis(LEDBAT, DONT_CARE_TRIG, 
			&(pup->addr_pair), dir, bufferbloat_stat, 
			&(otherdir->utp), conn_id, type, putplen, grossdelay,overfitting_avoided,
			it_is_a_data_pkt);

		float estimated_99P;
		float estimated_95P;
		float estimated_90P;
		float estimated_75P;

		if (windowed_qd != -1){
			estimated_99P=PSquare(thisdir, (int)windowed_qd, PERC_99);
			estimated_95P=PSquare(thisdir, (int)windowed_qd, PERC_95);
			estimated_90P=PSquare(thisdir, (int)windowed_qd, PERC_90);
			estimated_75P=PSquare(thisdir, (int)windowed_qd, PERC_75);
		}
	}

	#ifdef SEVERE_DEBUG
	check_direction_consistency(LEDBAT, DONT_CARE_TRIG, thisdir, __LINE__);
	#endif
	
	/*start of bittorrent message*/
	u_int8_t *pputp=NULL;
	u_int8_t *extchain=NULL;
	u_int8_t len;
	if (putp->ext == 0) {
	   pputp=((u_int8_t *) putp) + 20;
	 	  	wfprintf (fp_ledbat_logc, "%s %s ",
			HostName(pup->addr_pair.a_address), 
			ServiceName(pup->addr_pair.a_port));
  
	}else{
		extchain=((u_int8_t *) theheader) + 20;
		len=0; 
        	do {
		   	extchain=extchain + len;
			len=*(extchain+1) + 2 ;
		} while ( *extchain != 0 );
		extchain=extchain + len;
	   	pputp=extchain;
	}
	
	
	if (((u_long) pputp - (u_long) putp) < (u_long)putplen   ) {
		/*finished uTP header: handover to BitTorrent message parser... */
		parser_BitTorrentMessages(pputp, tproto, pdir, dir, hdr, plast);
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

void print_BitTorrentUDP_conn_stats (void *thisflow, int tproto){
  //<aa> All statistical updates are performed in different places now</aa>
  return;
	
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
	  if (utpstat.qd_samples_until_last_window>0) {
                		
		utpstat.queueing_delay_average_w1 = 
			utpstat.windowed_qd_sum / utpstat.qd_samples_until_last_window;

		int N = utpstat.qd_samples_until_last_window;
           
		utpstat.queueing_delay_standev_w1 =Stdev(
			utpstat.windowed_qd_sum, utpstat.windowed_qd_sum2,N );

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
          if (utpstat.qd_samples_until_last_window>0) {
               	utpstat.queueing_delay_average_w1=
			utpstat.windowed_qd_sum / utpstat.qd_samples_until_last_window;
                int N=utpstat.not_void_windows;
		utpstat.queueing_delay_standev_w1=
			Stdev(utpstat.windowed_qd_sum, utpstat.windowed_qd_sum2, N );

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

		//<aa>TODO: check how to correctly print non printable strings</aa>
		wfprintf(fp_ledbat_logc, "0x%X 0x%X ",
	     		strlen(utpstat.peerID)>0 ? utpstat.peerID : "----",    				     	strlen(utpstat.infoHASH)>0 ? utpstat.infoHASH : "----");
          }//if log_engine
          wfprintf (fp_ledbat_logc,"\n");
  }


}


float PSquare (void* pdir, float q, int p ){
	ucb *thisdir;
	thisdir = ( ucb *) pdir;
	int k = -1;
	float P=-1;


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

	//<aa>
	#ifdef SEVERE_DEBUG
	if(P<0){
		printf("line %d:ERROR in Psquare\n",__LINE__);exit(88);
	}
	#endif
	//</aa>



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
						
				//<aa>
				#ifdef SEVERE_DEBUG
				if(k<0){
					printf("line %d:ERROR in Psquare\n",__LINE__);
					exit(88);
				}
				#endif
				//</aa>

				int i=0;
				while ( i < 5){
					thisdir->utp.n_P[i][p]= thisdir->utp.n_P[i][p]+ thisdir->utp.dn_P[i][p];
					
					i++;
				}//update positions of markers
			

  //                              printf("\n before x[0  1  2  3  4 ] %f %f %f %f %f", thisdir->utp.x_99P[0], thisdir->utp.x_99P[1], thisdir->utp.x_99P[2], thisdir->utp.x_99P[3], thisdir->utp.x_99P[4] );
	
				int j = k;
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
