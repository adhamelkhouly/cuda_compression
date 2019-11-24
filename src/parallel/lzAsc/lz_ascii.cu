#include "lz_ascii.h"

__device__ void write_bits(uint32_t* tmp, int bits, uint16_t code, int size_per_thread_const, int* out_len, int* o_bits, uint8_t* out, int segment_num, int fork) {
	if (fork == 0) {
		*tmp = (*tmp << bits) | code;
	}
	else if (fork == 1) {
		*tmp = (*tmp << bits) | M_CLR;
	}
	else if (fork == 2) {
		*tmp = (*tmp << bits) | M_EOD;
	}
	else if (fork == 3) {
		*tmp = (*tmp << bits) | *tmp;
	}
	*o_bits = *o_bits + bits;
	if (size_per_thread_const <= *out_len) {
		printf("\nEncoding using more momery in this block ... Exiting\n");
		return;
	}
	while (*o_bits >= 8) {
		*o_bits = *o_bits - 8;
		out[(segment_num * size_per_thread_const) + *out_len] = *tmp >> *o_bits;
		*out_len = *out_len +1 ;
		*tmp = *tmp & ((1 << *o_bits) - 1);
	}
}

/****************Cuda Functions on GPU*************************/
//TODO: maybe change length parameters to size_t
__global__ void lz_encode_with_ascii_kernel(int threads_per_block, uint8_t* dev_in, int* segment_lengths, uint8_t* out, lzw_enc_t* dict, size_t size, int max_bits)
{
	//__shared__ int seg_length_gpu[NUM_OF_THREADS];
	__shared__ uint16_t next_code;
	next_code = M_NEW;
	__syncthreads();
	int size_per_thread_const = (size + (NUM_OF_THREADS - 1)) / NUM_OF_THREADS;
	int size_per_thread_change = size_per_thread_const;
	int size_dict_seg = sizeof(size_t) * 2 + 512 * sizeof(lzw_enc_t);
	int segment_num = (threadIdx.x + (blockIdx.x * threads_per_block));

	uint8_t* segment_input_ptr = &dev_in[segment_num * size_per_thread_const];

	int bits = 9, next_shift = 512;
	uint16_t code, c, nc;
	

	if (max_bits > 15) max_bits = 15;
	if (max_bits < 9) max_bits = 12;

	int out_len = 0;
	int o_bits = 0;
	uint32_t tmp = 0;

	for (code = *(segment_input_ptr++); size_per_thread_change > 0; --size_per_thread_change) {
		c = *(segment_input_ptr++);
		if (c == NULL) break;
		if ((nc = dict[code].next[c])) //if nc is not equal to 0 after assignment then enter if statment
			code = nc;
		else {
			write_bits(&tmp, bits, code, size_per_thread_const, &out_len, &o_bits, out, segment_num, 0);
			_Acquires_exclusive_lock_();
			nc = dict[code].next[c] = next_code++;
			_Releases_exclusive_lock_();
			code = c;
		}
		
		__syncthreads();
		if (next_code == next_shift) {
			
			/* either reset table back to 9 bits */
			//if (++bits > max_bits) {
				/* table clear marker must occur before bit reset */
				write_bits(&tmp, bits, code, size_per_thread_const, &out_len, &o_bits, out, segment_num, 1);

				bits = 9;
				next_shift = 512;
				__syncthreads();
				next_code = M_NEW;
				size_t* x = (size_t*)dict - 2;
				memset(dict, 0, x[0] * x[1]);
				__syncthreads();
			//}
			//else  /* or extend table */
			//{
			//	size_t* x = (size_t*)dict - 2; //go back two size_t's (64 bits in our definition) to get the previously stored item_size and number of items
			//	size_t* y = (size_t*)(&dict[x[0] * x[1]]);
			//	//y = (size_t*)malloc(*x * next_shift); //
			//	next_shift *= 2;
			//	if (next_shift > x[1]) //if actually more memory is asked for then initialize the extra with zeros till we fill it out in the future
			//		memset((char*)(x + 2) + x[0] * x[1], 0, x[0] * (next_shift - x[1]));
			//	x[1] = next_shift;
			//	dict = (lzw_enc_t*)x + 2;
			//}
		}
	}

	//write code
	write_bits(&tmp, bits, code, size_per_thread_const, &out_len, &o_bits, out, segment_num, 0);

	//write EOD
	if (threadIdx.x == NUM_OF_THREADS) {
		write_bits(&tmp, bits, code, size_per_thread_const, &out_len, &o_bits, out, segment_num, 2);
	}


	//write tmp
	if (tmp) {
		//write EOD
		write_bits(&tmp, bits, code, size_per_thread_const, &out_len, &o_bits, out, segment_num, 3);
	}
	segment_lengths[segment_num] = out_len;
	//free(y);
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

	printf("input size: %d\n", _len(in));

	lz_ascii_with_cuda(in);

	return 0;
}

cudaError_t lz_ascii_with_cuda(uint8_t* in)
{
	uint8_t* dev_in = 0;
	uint8_t* dev_final_out = 0;
	int* segment_lengths; //the added one is for total size of encoded msg
	size_t* x = 0;
	uint8_t* encoded = 0;
	clock_t start_t, end_t;

	start_t = clock();
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

	cudaStatus = cudaMallocManaged((void**)& segment_lengths, (NUM_OF_THREADS + 1) * sizeof(int));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}
	//cudaMemset(segment_lengths, 0, (NUM_OF_THREADS + 1)*sizeof(int));
	for (int i = 0; i < NUM_OF_THREADS + 1; i++) {
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

	lzw_enc_t* dict = (lzw_enc_t*)(x + 2);

	int numBlocks = ((NUM_OF_THREADS + (MAX_NUMBER_THREADS_PER_BLOCK - 1)) / MAX_NUMBER_THREADS_PER_BLOCK) +1 ;
	int threadsPerBlock = ((NUM_OF_THREADS + (numBlocks - 1)) / numBlocks);
	/*************************************** Parrallel Part of Execution **********************************************/
	lz_encode_with_ascii_kernel << <numBlocks, threadsPerBlock >> > (threadsPerBlock, dev_in, segment_lengths, dev_final_out, dict, _len(in), 9);

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
	
	end_t = clock();
	printf("\n time taken: %d \n",((end_t - start_t)));

	FILE* encodedFile = fopen("encoded_file.txt", "wb");
	printf("%d", sum);
	fwrite(encoded, sum, 1, encodedFile);

Error:
	// BE FREE MY LOVLIES
	cudaFree(dev_in);
	cudaFree(dev_final_out);
	cudaFree(segment_lengths);
	cudaFree(encoded);
	cudaFree(x);

	return cudaStatus;
}