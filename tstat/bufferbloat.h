#ifdef BUFFERBLOAT_ANALYSIS
#ifndef _BUFFERBLOAT_H_ 
#define _BUFFERBLOAT_H_


enum analysis_type { 
	TCP = 1,
	LEDBAT = 2
};

enum bufferbloat_analysis_trigger
{
	#ifdef DATA_TRIGGERED_BUFFERBLOAT_ANALYSIS
	DATA_TRIG, 
	#endif
	ACK_TRIG, 
	DONT_CARE_TRIG 
};

#define NO_MATTER -1

/**
 * type: <bit_torrent_client_1>:<bit_torrent_client2> for ledbat case. flowtype for tcp case
 * addr_pair: it can be also an udp_pair_addrblock* casted to tcp_pair_addrblock* .
 * - utp_conn_id: in the tcp case, it will be ignored
 * - estimated_qd (microseconds) (it will be printed on the logfile in milliseconds)
 * - dir: can be C2S or S2C
 * - last_gross_delay (microseconds) (it will be printed on the logfile in milliseconds)
 */
 #ifdef SAMPLES_BY_SAMPLES_LOG
#ifdef FORCE_CALL_INLINING
extern inline
#endif
void print_queueing_dly_sample(enum analysis_type an_type, 
	enum bufferbloat_analysis_trigger trig,
	const tcp_pair_addrblock* addr_pair, int dir,
	utp_stat* bufferbloat_stat_p, int utp_conn_id,u_int32_t estimated_qd, 
	const char* type, u_int32_t pkt_size, u_int32_t last_gross_delay)
#ifdef FORCE_CALL_INLINING
	__attribute__((always_inline))
#endif
;
#endif

/**
 * Estimates queueing delay, updates the data structure needed to calculate the queueing delay
 * and print queueing delay logs. Performs windowing operations too
 * - last_gross_delay (microseconds)
 * - return windowed queueing delay (microseconds) or -1 if the window was not closed
 */
float bufferbloat_analysis(enum analysis_type an_type,
	enum bufferbloat_analysis_trigger trig, const tcp_pair_addrblock* addr_pair, 
	const int dir, utp_stat* bufferbloat_stat, utp_stat* otherdir_bufferbloat_stat,
	int utp_conn_id, const char* type, u_int32_t pkt_size, u_int32_t last_gross_delay,
	Bool overfitting_avoided, Bool update_size_info);

#ifdef SAMPLES_VALIDITY
/**
 * ONLY FOR TCP BUFFERBLOAT ANALYSIS
 * Call it if a packet is received which cannot be used to perform bufferbloat computation
 * (for example, in the case of tcp ack-triggered analysis, you must call it when you 
 * receive a duplicate ack, an ack out of sequence, ....)
 */
void chance_is_not_valid(enum analysis_type an_type, 
	enum bufferbloat_analysis_trigger trig, const tcp_pair_addrblock* addr_pair,
	const int dir, const char* type, utp_stat* thisdir_bufferbloat_stat, 
	utp_stat* otherdir_bufferbloat_stat, const int conn_id );
#endif

//<aa>TODO: Try to pass the FILE* fp_logc directly, instead of passing
//an_type and trig and calculate fp_logc inside different functions</aa>
#ifdef FORCE_CALL_INLINING
extern inline
#endif
void print_last_window_general(enum analysis_type an_type,  
	enum bufferbloat_analysis_trigger trig, unsigned long long left_edge,
	const tcp_pair_addrblock* addr_pair,
	const utp_stat* bufferbloat_stat_p)
#ifdef FORCE_CALL_INLINING
	__attribute__((always_inline))
#endif
	;

//Use it as a signal when there are no samples in a window
#define BUFFEBLOAT_NOSAMPLES -1

/**
 * Print info for a specific direction
 * - qd_window:	queueing delay of the window (milliseconds) 
 *		(-1 if this window has non samples)
 * - conn_id:	it has no meaning for tcp analysis
 * - type:	//<aa>TODO: Maybe type is the same for both directions. Check this</aa>
 */
#ifdef FORCE_CALL_INLINING
extern inline
#endif
void print_last_window_directional(enum analysis_type an_type,
	enum bufferbloat_analysis_trigger trig,
	const utp_stat* bufferbloat_stat, const int conn_id, const char* type,
	const float qd_window, const float window_error)
#ifdef FORCE_CALL_INLINING
	__attribute__((always_inline))
#endif
;

#ifdef FORCE_CALL_INLINING
extern inline
#endif
void print_void_window(enum analysis_type an_type,  
	enum bufferbloat_analysis_trigger trig, const unsigned long long old_last_left_edge,
	const tcp_pair_addrblock* addr_pair, const utp_stat* thisdir_bufferbloat_stat,
	const utp_stat* otherdir_bufferbloat_stat, const int conn_id, const char* type)
#ifdef FORCE_CALL_INLINING
	__attribute__((always_inline))
#endif
;

//compute statistics
//<aa>
/**
 * If the previous window can be closed (i.e. more than 1s has passed), it closes it and 
 * returns the estimated queueing delay for that window. It returns -1 otherwise.
 * - qd: an estimate of the queueing delay of the packet
 */
#ifdef FORCE_CALL_INLINING
extern inline
#endif
float windowed_queueing_delay(enum analysis_type an_type, 
	enum bufferbloat_analysis_trigger trig, const tcp_pair_addrblock* addr_pair, 
	utp_stat* thisdir_bufferbloat_stat, utp_stat* otherdir_bufferbloat_stat, int dir, 
	const char* type, const int conn_id)
#ifdef FORCE_CALL_INLINING
	__attribute__((always_inline))
#endif
;
//</aa>


/**
 * It updates the left edge of the following not void window
 */
#ifdef FORCE_CALL_INLINING
extern inline
#endif
void update_following_left_edge(utp_stat* bufferbloat_stat)
#ifdef FORCE_CALL_INLINING
	__attribute__((always_inline))
#endif
;


/**
 * It closes the previous window and updates the values for the following one. 
 * It returns the queueing delay of the closed window (in milliseconds) or -1 if no 
 * pkts have been seen in the 
 * previous window.
 */
#ifdef FORCE_CALL_INLINING
extern inline
#endif
float close_window(enum analysis_type an_type, enum bufferbloat_analysis_trigger trig,
	utp_stat* bufferbloat_stat, const char* type, int conn_id)
#ifdef FORCE_CALL_INLINING
	__attribute__((always_inline))
#endif
;

/**
 */
#ifdef FORCE_CALL_INLINING
extern inline
#endif
void update_bufferbloat_windowed_values(utp_stat* bufferbloat_stat, float window_qd, 
	int qd_samples_in_win)
#ifdef FORCE_CALL_INLINING
	__attribute__((always_inline))
#endif
;


#ifdef SEVERE_DEBUG
//Check if the direction of the current packet and the opposite direction are handled
//consistently. If it is not the case, the program will terminate.
void check_direction_consistency(enum analysis_type an_type, 
	enum bufferbloat_analysis_trigger trig, void* thisdir_, int call_line_number);

void check_direction_consistency_light(const utp_stat* this_bufferbloat_stat, 
	const utp_stat* other_bufferbloat_stat, int caller_line);
#endif


#endif //of _BUFFERBLOAT_H_

#endif //of BUFFERBLOAT_ANALYSIS
