#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdlib.h>
#include <stdio.h>
#include <iostream>
#include <string>
#include <stdint.h>
#include <io.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <inttypes.h>
#include <time.h>

#define MAX_NUMBER_THREADS_PER_BLOCK 1024
#define NUM_OF_THREADS 512

#define M_CLR 256 /* clear table marker */
#define M_EOD 257 /* end-of-data marker */
#define M_NEW 258 /* new code index */

/************************ Macros ***************************/
#define _new(type, n) pc_heap_mem_alloc(sizeof(type), n)
#define _del(m)   { free((size_t*)(m) - 2); m = 0; }
#define _len(m)   *((size_t*)m - 1)
#define _setsize(m, n)  m = pc_heap_mem_extend(m, n)
#define _extend(m)  m = pc_heap_mem_extend(m, _len(m) * 2)


/*********************** Structs *************************/

/* encode and decode dictionary structures.
   for encoding, entry at code index is a list of indices that follow current one,
   i.e. if code 97 is 'a', code 387 is 'ab', and code 1022 is 'abc',
   then dict[97].next['b'] = 387, dict[387].next['c'] = 1022, etc. */
typedef struct {
	uint16_t next[256];
} lzw_enc_t;

/****************** Function Declarations***********************/
void* pc_heap_mem_alloc(size_t item_size, size_t n_item);
void* pc_heap_mem_extend(void* m, size_t new_n);
inline void _clear(void* m);
//inline void write_bits_encoder(uint16_t x);

cudaError_t lz_ascii_with_cuda(uint8_t* in);


__global__ void lz_encode_with_ascii_kernel(int threads_per_block, uint8_t* dev_in, int* segment_lengths, uint8_t* out, lzw_enc_t* dict, size_t size, int max_bits);

__global__ void populate(int threads_per_block, int* segment_lengths, uint8_t* out, uint8_t* encoded);

//__global__ void* gpu_mem_alloc(size_t item_type, size_t n_item);
//__global__ void* gpu_mem_extend(void* m, size_t new_n);
