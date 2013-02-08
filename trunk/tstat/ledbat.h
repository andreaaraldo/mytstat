#ifndef _LEDBAT_H_ 
#define _LEDBAT_H_




#define NOT_UTP 0
#define UTP_DATA 1
#define UTP_FIN 2
#define UTP_STATE_ACK 3
#define UTP_STATE_SACK 4
#define UTP_RESET 5
#define UTP_SYN 6

//parser BitTorrent
#define INITIALIZE 0
#define HANDSHAKE 1
#define HANDSHAKE_EXTENSIONS 2
#define HAVE 3
#define PIECE 4
#define BITFIELD 5



#define DELAY_BASE_UPDATE 10

#define UTP_BIG_ENDIAN 1


/**
 * <aa>
 * References
 * [ledbat_draft]: "Low Extra Delay Background Transport (LEDBAT) draft-ietf-ledbat-congestion-10.txt"
 * [utp_draft]: "uTorrent transport protocol" - http://www.bittorrent.org/beps/bep_0029.html
 * </aa>
 */


struct utp_hdr
{
#if UTP_BIG_ENDIAN
  unsigned int ver:4;		/* protocol version */
  unsigned int type:4;		/* type */
  unsigned int ext:8;		/* header extension */


#elif UTP_LITTLE_ENDIAN
  unsigned int type:4;		/* type */
  unsigned int ver:4;		/* protocol version */
  unsigned int ext:8;		/**
 * For every packet, this function must be called to update the statistics of the last window
 * 	time_ms: the timestamp of the packet (in microseconds - see [utp_draft])
 * 	qd: an estimate of the queueing delay
 */
float windowed_queueing_delay( void *pdir, u_int32_t time_ms, float qd);/* header extension */
  


#else
#error Define one of UTP_LITTLE_ENDIAN or UTP_BIG_ENDIAN
#endif
  u_int16_t conn_id:16;	/* connection id */

	//<aa>TODO: use us in place of ms</aa>
  u_int32_t time_ms:32;	/* timestamp microsecond */
  u_int32_t time_diff:32;	/* timestamp microsecond diff */
  u_int32_t wnd_size:32;	/* window size */
  u_int16_t seq_nr:16;	/* sequence number */
  u_int16_t ack_nr:16;	/* ack number */
  

};
typedef struct utp_hdr utp_hdr;



//struct bittorrent_hdr
//{
  //u_int32_t length:32;			/* length */
  //unsigned int id:8;		/* identificator */
//};
//typedef struct bittorrent_hdr bittorrent_hdr;



//typedef ipaddr ipaddr;
//typedef portnum portnum;

/*void print_BitTorrent_conn_stats (void *thisdir, int dir);*/
void print_BitTorrentUDP_conn_stats (void *thisflow, int tproto);

/**
 * <aa> For every packet, it updates the info about the communication between the pair of nodes exchanging that packet. 
 * pdir: the structure that conveys the info about the communication between the pair and that will be updated by this function
 * </aa>
 */
void parser_BitTorrentUDP_packet (struct ip *pip, void *pproto, int tproto, void *pdir,int dir, void *hdr, void *plast, int type_utp);//chiamata da flow stat 


/**
 * dir: can be C2S or S2C
 */
void parser_BitTorrentMessages (void *pp, int tproto, void *pdir,int dir, void *hdr, void *plast); 




/* plugin functions*/
void BitTorrent_init (); //questa per il momento non serve a niente  <aa> Called in plugin.c </aa>

//<aa>For each packet, if an utp header is recognized, it returns the pointer to that header. Otherwise, it returns NULL </aa>
struct utp_hdr *getBitTorrent (void *pproto, int tproto, void *pdir, void *plast); //questa forse non servirà mai a niente perchè l'abbiamo organizzato diverso

//void getBitTorrent (void *pproto, int tproto, void *pdir, void *plast); //questa forse non servirà mai a niente perchè l'abbiamo organizzato diverso
void BitTorrent_flow_stat (struct ip *pip, void *pproto, int tproto, void *pdir, int dir, void *hdr, void *last); //importantissima:chiamata dal protoanalyzer
void make_BitTorrent_conn_stats (void *thisdir, int tproto); //statistiche finali solo per il caso utp
void make_BitTorrentTCP_conn_stats (void *thisdir, int tproto); //statistiche finali per il caso tcp chiamata dal conn_stat di tcp 

//compute statistics
/** <aa>
 * If the previous window can be closed (i.e. more than 1s has passed), it closes it and 
 * returns the estimated queueing delay for that window. It returns -1 otherwise.
 * 	time_ms: the timestamp of the packet
 * 	qd: an estimate of the queueing delay of the packet
 * </aa>
 */
float windowed_queueing_delay( void *pdir, u_int32_t time_ms, float qd);


float PSquare(void *pdir, float q, int P);


#endif
