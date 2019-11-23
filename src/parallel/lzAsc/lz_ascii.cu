#include "lz_ascii.h"

/****************Cuda Functions on GPU*************************/
//TODO: has bugs, num of threads matter for the output size ... look into the looping part and synchronization
//TODO: maybe change length parameters to size_t
//TODO: add sum variable to keep track of total encoded length
__global__ void lz_encode_with_ascii_kernel(int threads_per_block, uint8_t* dev_in, int* segment_lengths, uint8_t* out, lzw_enc_t* dict, size_t size, int max_bits)
{
	//__shared__ int seg_length_gpu[NUM_OF_THREADS];
	int size_per_thread_const = (size + (NUM_OF_THREADS-1))/ NUM_OF_THREADS;
	int size_per_thread_change = size_per_thread_const;
	int size_dict_seg = sizeof(size_t) * 2 + 512 * sizeof(lzw_enc_t);
	int segment_num = (threadIdx.x + (blockIdx.x * threads_per_block));

	uint8_t* segment_input_ptr = &dev_in[segment_num * size_per_thread_const];

	int bits = 9, next_shift = 512;
	uint16_t code, c, nc, next_code = M_NEW;
	//size_t out_segment_size = sizeof(size_t) * 2 + 4 * sizeof(uint16_t);

	if (max_bits > 15) max_bits = 15;
	if (max_bits < 9) max_bits = 12;
	 
	/*size_t* y = (size_t*)malloc(out_segment_size);
	y[0] = sizeof(uint16_t);
	y[1] = 4;
	printf("%i\n", segment_num);
	out_final[segment_num] = (uint8_t*)(y[2]);*/
	//out[segment_num] = (uint8_t*)gpu_mem_alloc(sizeof(uint16_t), 4);

	int out_len = 0, o_bits = 0;
	uint32_t tmp = 0;

	//TODO: Look into making inline functions
	for (code = *(segment_input_ptr++); size_per_thread_change > 0; --size_per_thread_change) {
		c = *(segment_input_ptr++);
		if (c == NULL) break;
		if ((nc = dict[code].next[c])) //if nc is not equal to 0 after assignment then enter if statment
			code = nc;
		else {
			tmp = (tmp << bits) | code; //shifting tmp 9 bits to the left and adding code to the right bits
			o_bits += bits;
			if (size_per_thread_const <= out_len) {
				//TODO: Could be done better to accomodate for extra space per block ... adding 64 bytes per section for example
				printf("\nEncoding using more momery in this block ... Exiting\n");
				return;
				//size_t new_n = _len(out[segment_num]) * 2;
				//size_t* z = (size_t*)(out[segment_num] - 2); //go back two size_t's (64 bits in our definition) to get the previously stored item_size and number of items
				//cudaError_t cudaStatus = cudaMalloc((void**)& z, sizeof(size_t) * 2 + *z * new_n); //
				//if (new_n > z[1]) //if actually more memory is asked for then initialize the extra with zeros till we fill it out in the future
				//	memset((char*)(z + 2) + z[0] * z[1], 0, z[0] * (new_n - z[1]));
				//z[1] = new_n;
				//out[segment_num] = (uint8_t*)(z + 2);
				//out[segment_num] = (uint8_t*)gpu_mem_extend(out[segment_num], _len(out[segment_num]) * 2); //extend by doubling size
			}
			while (o_bits >= 8) { 	//checks for how many bytes it can write out of the bits given
				o_bits -= 8;
				//shifting o_bits to the right, shifting to the right means dividing by 2^(o_bits)
				//eleminating the leftover bits on the right to write one byte to the ouput
				out[(segment_num * size_per_thread_const) + out_len] = tmp >> o_bits;
				out_len++;
				//shift 1 to the left by o_bits, basically multiplying 1 by 2^(o_bits) ... then mask this value-1 on tmp
				//saving the leftover bits on the right from the previous line for the next iteration
				//e.x 1110 1110 11, tmp will be the 11 at the right
				tmp &= (1 << o_bits) - 1;
			}
			//_Acquires_exclusive_lock_();
			nc = dict[code].next[c] = next_code++;
			//_Releases_exclusive_lock_();
			code = c;
		}

		//if (next_code == next_shift) {
		//	/* either reset table back to 9 bits */
		//	if (++bits > max_bits) {
		//		/* table clear marker must occur before bit reset */
		//		tmp = (tmp << bits) | M_CLR; //shifting tmp 9 bits to the left and adding code to the right bits
		//		o_bits += bits;
		//		if (size_per_thread_const <= out_len) {
		//			//TODO: Could be done better to accomodate for extra space per block ... adding 64 bytes per section for example
		//			printf("\nEncoding using more momery in this block ... Exiting\n");
		//			return;
		//			//size_t new_n = _len(out[segment_num]) * 2;
		//			//size_t* z = (size_t*)(out[segment_num] - 2); //go back two size_t's (64 bits in our definition) to get the previously stored item_size and number of items
		//			//cudaError_t cudaStatus = cudaMalloc((void**)& z, sizeof(size_t) * 2 + *z * new_n); //
		//			//if (new_n > z[1]) //if actually more memory is asked for then initialize the extra with zeros till we fill it out in the future
		//			//	memset((char*)(z + 2) + z[0] * z[1], 0, z[0] * (new_n - z[1]));
		//			//z[1] = new_n;
		//			//out[segment_num] = (uint8_t*)(z + 2);
		//			//out[segment_num] = (uint8_t*)gpu_mem_extend(out[segment_num], _len(out[segment_num]) * 2); //extend by doubling size
		//		}
		//		while (o_bits >= 8) { 	//checks for how many bytes it can write out of the bits given
		//			o_bits -= 8;
		//			//shifting o_bits to the right, shifting to the right means dividing by 2^(o_bits)
		//			//eleminating the leftover bits on the right to write one byte to the ouput
		//			out[(segment_num * size_per_thread_const) + out_len] = tmp >> o_bits;
		//			out_len++;
		//			//shift 1 to the left by o_bits, basically multiplying 1 by 2^(o_bits) ... then mask this value-1 on tmp
		//			//saving the leftover bits on the right from the previous line for the next iteration
		//			//e.x 1110 1110 11, tmp will be the 11 at the right
		//			tmp &= (1 << o_bits) - 1;
		//		}

		//		bits = 9;
		//		next_shift = 512;
		//		next_code = M_NEW;
		//		size_t* x = (size_t*)dict - 2;
		//		memset(dict, 0, x[0] * x[1]);
		//		//_clear(dict);
		//	}
		//	else  /* or extend table */
		//	{
		//		//next_shift *= 2;
		//		size_t* x = (size_t*)dict - 2; //go back two size_t's (64 bits in our definition) to get the previously stored item_size and number of items
		//		size_t* y = (size_t*)(&dict[x[0] * x[1]]);
		//		y = (size_t*)malloc(*x * next_shift); //
		//		next_shift *= 2;
		//		if (next_shift > x[1]) //if actually more memory is asked for then initialize the extra with zeros till we fill it out in the future
		//			memset((char*)(x + 2) + x[0] * x[1], 0, x[0] * (next_shift - x[1]));
		//		x[1] = next_shift;
		//		dict = (lzw_enc_t*)x + 2;
		//	}
		//		//_setsize(dict, next_shift *= 2);
		//}
	}

	//write code
	tmp = (tmp << bits) | code; //shifting tmp 9 bits to the left and adding code to the right bits
	o_bits += bits;
	if (size_per_thread_const <= out_len) {
		//TODO: Could be done better to accomodate for extra space per block ... adding 64 bytes per section for example
		printf("\nEncoding using more momery in this block ... Exiting\n");
		return;
		//size_t new_n = _len(out[segment_num]) * 2;
		//size_t* z = (size_t*)(out[segment_num] - 2); //go back two size_t's (64 bits in our definition) to get the previously stored item_size and number of items
		//cudaError_t cudaStatus = cudaMalloc((void**)& z, sizeof(size_t) * 2 + *z * new_n); //
		//if (new_n > z[1]) //if actually more memory is asked for then initialize the extra with zeros till we fill it out in the future
		//	memset((char*)(z + 2) + z[0] * z[1], 0, z[0] * (new_n - z[1]));
		//z[1] = new_n;
		//out[segment_num] = (uint8_t*)(z + 2);
		//out[segment_num] = (uint8_t*)gpu_mem_extend(out[segment_num], _len(out[segment_num]) * 2); //extend by doubling size
	}
	while (o_bits >= 8) { 	//checks for how many bytes it can write out of the bits given
		o_bits -= 8;
		//shifting o_bits to the right, shifting to the right means dividing by 2^(o_bits)
		//eleminating the leftover bits on the right to write one byte to the ouput
		out[(segment_num * size_per_thread_const) + out_len] = tmp >> o_bits;
		out_len++;
		//shift 1 to the left by o_bits, basically multiplying 1 by 2^(o_bits) ... then mask this value-1 on tmp
		//saving the leftover bits on the right from the previous line for the next iteration
		//e.x 1110 1110 11, tmp will be the 11 at the right
		tmp &= (1 << o_bits) - 1;
	}

	//write EOD
	if (threadIdx.x == NUM_OF_THREADS) {
		tmp = (tmp << bits) | M_EOD; //shifting tmp 9 bits to the left and adding code to the right bits
		o_bits += bits;
		if (size_per_thread_const <= out_len) {
			//TODO: Could be done better to accomodate for extra space per block ... adding 64 bytes per section for example
			printf("\nEncoding using more momery in this block ... Exiting\n");
			return;
			//size_t new_n = _len(out[segment_num]) * 2;
			//size_t* z = (size_t*)(out[segment_num] - 2); //go back two size_t's (64 bits in our definition) to get the previously stored item_size and number of items
			//cudaError_t cudaStatus = cudaMalloc((void**)& z, sizeof(size_t) * 2 + *z * new_n); //
			//if (new_n > z[1]) //if actually more memory is asked for then initialize the extra with zeros till we fill it out in the future
			//	memset((char*)(z + 2) + z[0] * z[1], 0, z[0] * (new_n - z[1]));
			//z[1] = new_n;
			//out[segment_num] = (uint8_t*)(z + 2);
			//out[segment_num] = (uint8_t*)gpu_mem_extend(out[segment_num], _len(out[segment_num]) * 2); //extend by doubling size
		}
		while (o_bits >= 8) { 	//checks for how many bytes it can write out of the bits given
			o_bits -= 8;
			//shifting o_bits to the right, shifting to the right means dividing by 2^(o_bits)
			//eleminating the leftover bits on the right to write one byte to the ouput
			out[(segment_num * size_per_thread_const) + out_len] = tmp >> o_bits;
			out_len++;
			//shift 1 to the left by o_bits, basically multiplying 1 by 2^(o_bits) ... then mask this value-1 on tmp
			//saving the leftover bits on the right from the previous line for the next iteration
			//e.x 1110 1110 11, tmp will be the 11 at the right
			tmp &= (1 << o_bits) - 1;
		}
	}
	

	//write tmp
	if (tmp) {
		//write EOD
		tmp = (tmp << bits) | tmp; //shifting tmp 9 bits to the left and adding code to the right bits
		o_bits += bits;
		if (size_per_thread_const <= out_len) {
			//TODO: Could be done better to accomodate for extra space per block ... adding 64 bytes per section for example
			printf("\nEncoding using more momery in this block ... Exiting\n");
			return;
			//size_t new_n = _len(out[segment_num]) * 2;
			//size_t* z = (size_t*)(out[segment_num] - 2); //go back two size_t's (64 bits in our definition) to get the previously stored item_size and number of items
			//cudaError_t cudaStatus = cudaMalloc((void**)& z, sizeof(size_t) * 2 + *z * new_n); //
			//if (new_n > z[1]) //if actually more memory is asked for then initialize the extra with zeros till we fill it out in the future
			//	memset((char*)(z + 2) + z[0] * z[1], 0, z[0] * (new_n - z[1]));
			//z[1] = new_n;
			//out[segment_num] = (uint8_t*)(z + 2);
			//out[segment_num] = (uint8_t*)gpu_mem_extend(out[segment_num], _len(out[segment_num]) * 2); //extend by doubling size
		}
		while (o_bits >= 8) { 	//checks for how many bytes it can write out of the bits given
			o_bits -= 8;
			//shifting o_bits to the right, shifting to the right means dividing by 2^(o_bits)
			//eleminating the leftover bits on the right to write one byte to the ouput
			out[(segment_num * size_per_thread_const) + out_len] = tmp >> o_bits;
			out_len++;
			//shift 1 to the left by o_bits, basically multiplying 1 by 2^(o_bits) ... then mask this value-1 on tmp
			//saving the leftover bits on the right from the previous line for the next iteration
			//e.x 1110 1110 11, tmp will be the 11 at the right
			tmp &= (1 << o_bits) - 1;
		}
	}

	segment_lengths[segment_num] = out_len;
	//_Acquires_exclusive_lock_();
	//segment_lengths[NUM_OF_THREADS] += out_len;
	//_Releases_exclusive_lock_();
	//uint8_t* final_segment_out = (uint8_t*)malloc(out_len);
	//memcpy(final_segment_out, &out[(segment_num * size_per_thread_const)], out_len);
	//out_ptrs[segment_num] = final_segment_out;
	
	//TODO: Make sure synchronizations are good
}

__global__ void populate(int threads_per_block, size_t size, int* segment_lengths, uint8_t* out, uint8_t* encoded) {
	int segment_num = (threadIdx.x + (blockIdx.x * threads_per_block));
	int size_per_thread_const = (size + (NUM_OF_THREADS - 1)) / NUM_OF_THREADS;
	int writing_pos = 0;
	for (int z = 0; z < segment_num; z++) {
		writing_pos += segment_lengths[z];
	}
	memcpy(&encoded[writing_pos], &out[(segment_num * size_per_thread_const)], segment_lengths[segment_num]);
}
//__global__ void* gpu_mem_alloc(size_t item_type, size_t n_item) {
//	size_t* x = nullptr;
//	cudaError_t cudaStatus = cudaMalloc((void**)& x, sizeof(size_t) * 2 + n_item * sizeof(item_type));
//	if (cudaStatus != cudaSuccess) {
//		fprintf(stderr, "cudaMalloc failed!");
//		return;
//	}
//	x[0] = sizeof(item_type);
//	x[1] = n_item;
//	return x+2;
//}
//
//__global__ void* gpu_mem_extend(void* m, size_t new_n)
//{
//	size_t* x = (size_t*)m - 2; //go back two size_t's (64 bits in our definition) to get the previously stored item_size and number of items
//	cudaError_t cudaStatus = cudaMalloc((void**)& x, sizeof(size_t) * 2 + *x * new_n); //
//	if (new_n > x[1]) //if actually more memory is asked for then initialize the extra with zeros till we fill it out in the future
//		cudaMemset((char*)(x + 2) + x[0] * x[1], 0, x[0] * (new_n - x[1]));
//	x[1] = new_n;
//	return x + 2;
//}

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

inline void _clear(void* m)
{
	size_t* x = (size_t*)m - 2;
	memset(m, 0, x[0] * x[1]);
}
/************************************************************/

int main(int argc, char* argv[])
{
	int i, fd = open("test.txt", O_RDONLY);
	if (fd == -1) {
		fprintf(stderr, "Can't read file\n");
		return 1;
	};

	struct stat st;
	fstat(fd, &st);

	uint8_t* in = (uint8_t*)_new(unsigned char, st.st_size);
	read(fd, in, st.st_size);
	//_setsize(in, st.st_size);
	close(fd);

	printf("input size:   %d\n", _len(in));

	lz_ascii_with_cuda(in);

	return 0;
}

cudaError_t lz_ascii_with_cuda(uint8_t* in)
{
	//TODO: Look into array of pointers again with each pointer pointing to an array which is malloced to max size of segment
	uint8_t* dev_in = 0;
	uint8_t* dev_final_out = 0;
	int * segment_lengths; //the added one is for total size of encoded msg
	size_t* x = 0;
	uint8_t* encoded = 0;
	clock_t start_t, end_t;

	// Choose which GPU to run on, change this on a multi-GPU system.
	cudaError_t cudaStatus = cudaSetDevice(0);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaSetDevice failed!  Do you have a CUDA-capable GPU installed?");
		goto Error;
	}

	cudaStatus = cudaMallocManaged((void**)& dev_in, _len(in) * sizeof(uint8_t));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}

	cudaMemcpy(dev_in, in, _len(in) * sizeof(unsigned char), cudaMemcpyKind::cudaMemcpyHostToDevice);

	cudaStatus = cudaMallocManaged((void**)& segment_lengths, (NUM_OF_THREADS+1) * sizeof(int));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}
	//cudaMemset(segment_lengths, 0, (NUM_OF_THREADS + 1)*sizeof(int));
	for (int i = 0; i < NUM_OF_THREADS+1; i++) {
		segment_lengths[i] = 0;
	}

	cudaStatus = cudaMallocManaged((void**)& dev_final_out, _len(in) * sizeof(uint8_t));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}

	//cudaMemset(dev_final_out, 0, _len(in));

	cudaStatus = cudaMallocManaged((void**)& x, (sizeof(size_t) * 2 + 512 * sizeof(lzw_enc_t)));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}

	x[0] = sizeof(lzw_enc_t);
	x[1] = 512;
	
	lzw_enc_t* dict = (lzw_enc_t*)(x+2);

	int numBlocks = ((NUM_OF_THREADS + (MAX_NUMBER_THREADS_PER_BLOCK - 1)) / MAX_NUMBER_THREADS_PER_BLOCK)+1;
	int threadsPerBlock = ((NUM_OF_THREADS + (numBlocks - 1)) / numBlocks);
	/*************************************** Parrallel Part of Execution **********************************************/
	start_t = clock();
	lz_encode_with_ascii_kernel << <numBlocks, threadsPerBlock >> > (threadsPerBlock, dev_in, segment_lengths, dev_final_out, dict, _len(in), 9);
	end_t = clock();
	/*****************************************************************************************************************/
	//printf("-- Number of Threads: %d -- Execution Time (ms): %g \n", numOfThreads, gpuTimer.Elapsed());
	// Check for any errors launching the kernel
	cudaStatus = cudaGetLastError();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "launch failed: %s\n", cudaGetErrorString(cudaStatus));
		goto Error;
	}

	// cudaDeviceSynchronize waits for the kernel to finish, and returns
	// any errors encountered during the launch.
	cudaStatus = cudaDeviceSynchronize();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "returned error code %d after launching !\n", cudaStatus);
		goto Error;
	}

	int sum = 0;
	for (int z = 0; z < NUM_OF_THREADS; z++) {
		sum += segment_lengths[z];
	}
	cudaStatus = cudaMallocManaged((void**)& encoded, sum * sizeof(uint8_t));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}
	
	/*************************************** Parrallel Part of Execution **********************************************/
	populate << <numBlocks, threadsPerBlock >> > (threadsPerBlock, _len(in), segment_lengths, dev_final_out, encoded);
	/*****************************************************************************************************************/

	cudaStatus = cudaGetLastError();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "launch failed: %s\n", cudaGetErrorString(cudaStatus));
		goto Error;
	}

	// cudaDeviceSynchronize waits for the kernel to finish, and returns
	// any errors encountered during the launch.
	cudaStatus = cudaDeviceSynchronize();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "returned error code %d after launching !\n", cudaStatus);
		goto Error;
	}

	//stitching shits together sequentially
	//int segment_length = 0;
	//uint8_t* tmp_out = (uint8_t*)malloc(_len(in));
	//memset(tmp_out, 0, _len(in));
	//int total_outsize = 0;
	//int segment_size = (_len(in) + (NUM_OF_THREADS - 1)) / NUM_OF_THREADS;
	//for (int x = 0; x < NUM_OF_THREADS; x++) {
	//	int segment_outlen = 0;
	//	while (dev_final_out[(x * segment_size) + segment_outlen] != NULL) {
	//		tmp_out[total_outsize] = dev_final_out[(x * segment_size) + segment_outlen];
	//		total_outsize++;
	//		segment_outlen++;
	//	}
	//	/*if (dev_final_out[(x * segment_size) + segment_outlen] == NULL) {
	//		total_outsize--;
	//		segment_outlen--;
	//		tmp_out[total_outsize] = 0;
	//		printf("testing");
	//	}*/
	//}
	//uint8_t* final_out = (uint8_t*)malloc(total_outsize);
	//memcpy(final_out, tmp_out, total_outsize);
	//free(tmp_out);

	printf("\n time taken: %ld: \n", end_t - start_t);
	//printf("%i", total_outsize);

	//TODO: hopefully we can decode segments of equal sizes, or should we keep M_EOD
	FILE* encodedFile = fopen("encoded_file.txt", "wb");
	//for (int i = 0; i < _len(in); i = i - 256) {
	fwrite(encoded, sum, 1, encodedFile);
	//}
	
Error:
	// BE FREE MY LOVLIES
	cudaFree(dev_in);
	cudaFree(dev_final_out);
	cudaFree(x);
	
	return cudaStatus;
}