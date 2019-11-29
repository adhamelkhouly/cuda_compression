#include "cuda.h"
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
#define NUM_OF_THREADS 64

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
//TODO: prob delete these two lines
void* pc_heap_mem_alloc(size_t item_size, size_t n_item);
void* pc_heap_mem_extend(void* m, size_t new_n);

cudaError_t lz_ascii_with_cuda(uint8_t* in, int num_of_threads);


__global__ void lz_encode_with_ascii_kernel(int threads_per_block, int num_of_threads, uint8_t* dev_in, int* segment_lengths, uint8_t* out, size_t size);

__global__ void populate(int threads_per_block, int num_of_threads, size_t size, int* segment_lengths, uint8_t* out, uint8_t* encoded);

/*******************Helper Functions***************************/
//Pass in item_size in bytes and how many items to allocate on the heap
void* pc_heap_mem_alloc(size_t item_size, size_t n_item)
{
	size_t* x = (size_t*)calloc(1, sizeof(size_t) * 2 + n_item * item_size);
	x[0] = item_size; //in bytes
	x[1] = n_item;
	return x + 2; //return pointer starting at data
}

void* pc_heap_mem_extend(void* m, size_t new_n)
{
	size_t* x = (size_t*)m - 2; //go back two size_t's (64 bits in our definition) to get the previously stored item_size and number of items
	x = (size_t*)realloc(x, sizeof(size_t) * 2 + *x * new_n); //
	if (new_n > x[1]) //if actually more memory is asked for then initialize the extra with zeros till we fill it out in the future
		memset((char*)(x + 2) + x[0] * x[1], 0, x[0] * (new_n - x[1]));
	x[1] = new_n;
	return x + 2;
}